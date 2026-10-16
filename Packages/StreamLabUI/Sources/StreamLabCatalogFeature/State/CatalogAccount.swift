import Combine
import Foundation
import StreamLabPresentation

/// Explicit demo-account lifecycle. This does not implement authentication/token revocation.
@MainActor public final class CatalogAccount: ObservableObject {
    @Published public private(set) var isSignedOut = false
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?
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
            let storage = AccountLocalData(root: try DurableMutationStore.defaultDirectory(),
                                           accountID: configuration.id, defaults: configuration.defaults)
            self.storage = storage
            isSignedOut = storage.isSignedOut
        } catch {
            isSignedOut = true
            errorMessage = "계정 저장소를 열지 못했습니다. 앱을 다시 실행해 주세요."
        }
    }

    public func logout(session: CatalogSession?) async {
        guard !isBusy else { return }
        isBusy = true
        isSignedOut = true
        errorMessage = nil
        session?.invalidate(saveProgress: false)
        defer { isBusy = false }
        do {
            guard let storage else { throw CocoaError(.fileReadUnknown) }
            let devices = try storage.beginLogout()
            await session?.waitForSync()
            try await CatalogSession.clearMockAccount(storage.accountID, devices: devices)
            try storage.finishCleanup()
            PlaybackSyncDemo.reset()
        } catch {
            errorMessage = "로컬 기록 삭제를 완료하지 못했습니다. 다시 시도해 주세요."
        }
    }

    public func signInDemo() async {
        guard isSignedOut, !isBusy else { return }
        // Repeat cleanup after relaunch or failure before allowing any new session.
        await logout(session: nil)
        guard errorMessage == nil, let storage else { return }
        do {
            try storage.signIn()
            isSignedOut = false
        } catch {
            errorMessage = "데모를 시작하지 못했습니다. 다시 시도해 주세요."
        }
    }
}
