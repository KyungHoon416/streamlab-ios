import Combine
import Foundation
import StreamLabPresentation

/// Local demo credentials in Keychain. No server login or real password authentication.
@MainActor public final class CatalogAccount: ObservableObject {
    @Published public private(set) var isSignedOut = true
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isRestoring = true
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
        do {
            let configuration = Self.configuration()
            storage = AccountLocalData(root: try DurableMutationStore.defaultDirectory(),
                                       accountID: configuration.id, defaults: configuration.defaults)
            // Demo-only namespace; these locally issued credentials never authenticate a server.
            tokenStore = try KeychainTokenStore(service: "com.streamlab.demo.authentication.v1")
        } catch {
            errorMessage = "계정 저장소를 열지 못했습니다. 앱을 다시 실행해 주세요."
        }
    }

    private nonisolated static func demoTokens() -> AccountTokens {
        AccountTokens(accessToken: "demo-access-" + UUID().uuidString,
                      refreshToken: "demo-refresh-" + UUID().uuidString)
    }

    /// No account content is shown until local cleanup state and Keychain agree.
    public func prepare() async {
        guard !prepared else { return }
        prepared = true
        isBusy = true
        defer { isBusy = false; isRestoring = false }
        do {
            guard let storage, let tokenStore else { throw CocoaError(.fileReadUnknown) }
            let tokenSignedOut = try await tokenStore.hasLogoutMarker(account: storage.accountID)
            if storage.isSignedOut || tokenSignedOut {
                try await cleanup(session: nil)
            } else {
                authentication = try await AuthenticationSession.restore(account: storage.accountID, store: tokenStore) { _ in
                    Self.demoTokens()
                }
                isSignedOut = authentication == nil
            }
        } catch {
            isSignedOut = true
            errorMessage = "데모 계정을 복원하지 못했습니다. 기기 잠금을 해제한 뒤 다시 시도해 주세요."
        }
    }

    private func cleanup(session: CatalogSession?) async throws {
        guard let storage, let tokenStore else { throw CocoaError(.fileReadUnknown) }
        await authentication?.invalidate()
        authentication = nil
        // Attempt both durable markers even if either storage is unavailable.
        let localLogout = Result { try storage.beginLogout() }
        try await tokenStore.signOut(account: storage.accountID)
        let devices = try localLogout.get()
        await session?.waitForSync()
        try await CatalogSession.clearMockAccount(storage.accountID, devices: devices)
        try storage.finishCleanup()
        PlaybackSyncDemo.reset()
    }

    public func logout(session: CatalogSession?) async {
        guard !isBusy else { return }
        isBusy = true
        isSignedOut = true
        errorMessage = nil
        session?.invalidate(saveProgress: false)
        defer { isBusy = false }
        do { try await cleanup(session: session) }
        catch { errorMessage = "로그아웃 정리를 완료하지 못했습니다. 다시 시도해 주세요." }
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
        } catch {
            errorMessage = "데모 로그인을 완료하지 못했습니다. 기기 잠금을 해제한 뒤 다시 시도해 주세요."
        }
    }
}
