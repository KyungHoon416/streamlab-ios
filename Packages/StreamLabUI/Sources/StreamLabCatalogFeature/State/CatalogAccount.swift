import Combine
import Foundation
import OSLog
import UIKit
import Security
import StreamLabDesignSystem
import StreamLabPresentation

/// Local demo credentials in Keychain. No server login or real password authentication.
@MainActor public final class CatalogAccount: ObservableObject {
    @Published public private(set) var isSignedOut = true
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isRestoring = true
    @Published public private(set) var waitingForProtectedData = false
    #if DEBUG
    private var simulatedLock = ProcessInfo.processInfo.arguments.contains("--ui-test-auth-locked-start")
    public func simulateProtectedDataUnlock() {
        simulatedLock = false
        NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
    }
    #endif
    private var protectedDataAvailable: Bool {
        #if DEBUG
        if simulatedLock { return false }
        #endif
        return UIApplication.shared.isProtectedDataAvailable
    }
    private var prepared = false
    private var tokenStore: KeychainTokenStore?
    private var authentication: AuthenticationSession?
    private var storage: AccountLocalData?

    static func configuration() -> (id: String, defaults: UserDefaults) {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-test-progress-suite=") }) {
            let name = String(argument.dropFirst("--ui-test-progress-suite=".count))
            if let defaults = UserDefaults(suiteName: name) { return ("ui-test-" + name, defaults) }
        }
        #endif
        return ("local-demo", .standard)
    }

    public init() {
        let span = HomeStartupTrace.begin("AccountInit")
        defer { withExtendedLifetime(span) {} }
    }

    private func openStores() throws {
        guard storage == nil || tokenStore == nil else { return }
        let configuration = Self.configuration()
        storage = AccountLocalData(root: try DurableMutationStore.defaultDirectory(),
                                   accountID: configuration.id, defaults: configuration.defaults)
        tokenStore = try KeychainTokenStore(service: "com.streamlab.demo.authentication.v1")
    }

    private func report(_ error: any Error, operation: String, message: String) {
        // Never stringify arbitrary errors: a provider error could contain credentials.
        let code: String
        if let tokenError = error as? TokenStoreError {
            switch tokenError {
            case .status(let status): code = "keychain:\(status)"
            case .invalidScope: code = "invalid-scope"
            case .invalidTokens: code = "invalid-tokens"
            case .corruptItem: code = "corrupt-item"
            case .corruptLogoutMarker: code = "corrupt-logout-marker"
            }
        } else if error is AuthenticationError {
            code = "authentication-error"
        } else {
            code = "storage-code:\((error as NSError).code)"
        }
        Logger(subsystem: "com.example.streamlab.demo", category: "DemoAuthentication")
            .error("operation=\(operation, privacy: .public) code=\(code, privacy: .public)")
        #if DEBUG
        errorMessage = message + " [" + operation + " · " + code + "]"
        #else
        errorMessage = message
        #endif
    }

    private nonisolated static func demoTokens() -> AccountTokens {
        AccountTokens(accessToken: "demo-access-" + UUID().uuidString,
                      refreshToken: "demo-refresh-" + UUID().uuidString)
    }

    /// No account content is shown until local cleanup state and Keychain agree.
    public func prepare() async {
        guard !prepared, !isBusy else { return }
        guard protectedDataAvailable else {
            waitingForProtectedData = true
            isRestoring = true
            return
        }
        prepared = true
        waitingForProtectedData = false
        errorMessage = nil
        isBusy = true
        defer { isBusy = false; isRestoring = waitingForProtectedData }
        do {
            try openStores()
            guard let storage, let tokenStore else { throw CocoaError(.fileReadUnknown) }
            let tokenSignedOut = try await tokenStore.hasLogoutMarker(account: storage.accountID)
            if storage.isSignedOut || tokenSignedOut {
                try await cleanup(session: nil)
            } else {
                authentication = try await AuthenticationSession.restore(account: storage.accountID, store: tokenStore) { _ in
                    Self.demoTokens()
                }
                isSignedOut = authentication == nil
                if !isSignedOut { await OfflineDownloadStore.shared.activate(accountID: storage.accountID) }
            }
        } catch {
            isSignedOut = true
            // Lock can arrive after the preflight while an actor operation is in flight.
            // Do not replace credentials or expose sign-in just because Keychain is locked.
            if !protectedDataAvailable || (error as? TokenStoreError) == .status(errSecInteractionNotAllowed) {
                prepared = false
                waitingForProtectedData = true
                return
            }
            report(error, operation: "restore", message: "데모 계정을 복원하지 못했습니다. 다시 시도해 주세요.")
        }
    }

    private func cleanup(session: CatalogSession?) async throws {
        guard let storage, let tokenStore else { throw CocoaError(.fileReadUnknown) }
        await authentication?.invalidate()
        authentication = nil
        // Attempt both durable markers even if either storage is unavailable.
        let localLogout = Result { try storage.beginLogout() }
        try await tokenStore.signOut(account: storage.accountID)
        try await OfflineDownloadStore.shared.clear(accountID: storage.accountID)
        let devices = try localLogout.get()
        await session?.waitForSync()
        try await CatalogSession.clearMockAccount(storage.accountID, devices: devices)
        try storage.finishCleanup()
        PlaybackSyncDemo.reset()
    }

    public func logout(session: CatalogSession?) async {
        guard !isBusy else { return }
        OfflineDownloadStore.shared.suppressCompletionNotifications()
        isBusy = true
        isSignedOut = true
        errorMessage = nil
        session?.invalidate(saveProgress: false)
        defer { isBusy = false }
        do { try await cleanup(session: session) }
        catch { report(error, operation: "logout", message: "로그아웃 정리를 완료하지 못했습니다. 다시 시도해 주세요.") }
    }

    public func signInDemo() async {
        guard isSignedOut, !isBusy, !isRestoring else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            guard let storage, let tokenStore else { throw CocoaError(.fileReadUnknown) }
            // Preserve existing demo records on the first upgrade. Only an explicit
            // prior logout requires data cleanup before a new sign-in.
            let tokenSignedOut = try await tokenStore.hasLogoutMarker(account: storage.accountID)
            if storage.isSignedOut || tokenSignedOut { try await cleanup(session: nil) }
            let fresh = try await AuthenticationSession.signIn(account: storage.accountID,
                tokens: Self.demoTokens(), store: tokenStore) { _ in Self.demoTokens() }
            authentication = fresh
            if storage.isSignedOut {
                do { try storage.signIn() }
                catch {
                    try await fresh.logout()
                    authentication = nil
                    throw error
                }
            }
            isSignedOut = false
            await OfflineDownloadStore.shared.activate(accountID: storage.accountID)
        } catch {
            report(error, operation: "sign-in", message: "데모 로그인을 완료하지 못했습니다. 다시 시도해 주세요.")
        }
    }
}
