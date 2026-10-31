#if DEBUG
import SwiftUI
import UIKit
import Security
import StreamLabPresentation

/// Opt-in hardware check. Never reads or changes the demo account's credentials.
@MainActor public struct KeychainLockDiagnosticView: View {
    @StateObject private var probe = KeychainLockProbe()
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Keychain 잠금 검증").font(.title)
                Text("암호가 설정된 실기기에서 시작한 뒤 측면 버튼으로 잠그세요. 10초 후 잠금을 해제하고 앱으로 돌아오세요. 실제 계정은 변경하지 않습니다.")
                Text(probe.status).accessibilityIdentifier("keychain-lock-status")
                Button("검증 시작") { probe.start() }
                    .disabled(probe.running)
                    .accessibilityIdentifier("keychain-lock-start")
                Button("중단 및 더미 정리") { probe.cancel() }
                    .disabled(!probe.running)
                    .accessibilityIdentifier("keychain-lock-cancel")
                Text("PASS는 잠금 중 -25308 확인, 해제 후 같은 값 읽기, 삭제 확인을 모두 마친 경우에만 표시합니다. 앱이 종료되면 결과는 미확인입니다.")
                    .font(.footnote)
            }.padding()
        }
        .onDisappear { probe.cancel() }
    }
}

@MainActor private final class KeychainLockProbe: ObservableObject {
    @Published var status = "대기 중"
    @Published var running = false
    private var task: Task<Void, Never>?
    private var background: UIBackgroundTaskIdentifier = .invalid

    func start() {
        guard !running else { return }
        running = true
        status = "더미 항목 준비 중"
        background = UIApplication.shared.beginBackgroundTask(withName: "KeychainLockDiagnostic") { [weak self] in
            Task { @MainActor in self?.cancel() }
        }
        task = Task { await run() }
    }

    func cancel() { task?.cancel() }
    private func endBackground() {
        if background != .invalid {
            UIApplication.shared.endBackgroundTask(background)
            background = .invalid
        }
    }

    private func run() async {
        // Fixed diagnostic-only namespace lets the next attempt clean up after a killed process.
        let account = "lock-probe"
        var store: KeychainTokenStore?
        var outcome = "미확인: 잠금 상태를 관측하지 못했습니다."
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KeychainLockProbe", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            let created = try KeychainTokenStore(service: "com.streamlab.diagnostics.lock-probe.v1", logoutDirectory: directory)
            store = created
            try await created.delete(account: account)
            let tokens = AccountTokens(accessToken: "dummy-lock-access", refreshToken: "dummy-lock-refresh")
            try await created.save(tokens, account: account)
            guard try await created.read(account: account) == tokens else { throw ProbeError.mismatch }
            status = "준비 완료: 지금 기기를 잠그고 10초 후 해제하세요."
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(60))
            var denied = false
            while clock.now < deadline {
                try Task.checkCancellation()
                if !UIApplication.shared.isProtectedDataAvailable {
                    do {
                        _ = try await created.read(account: account)
                        // Keybag locking may follow the notification. Poll rather than treating
                        // a transitional successful read as a security failure.
                    } catch TokenStoreError.status(let code) where code == errSecInteractionNotAllowed {
                        denied = true
                        status = "잠금 중 읽기 차단 확인 (-25308). 잠금을 해제하세요."
                        break
                    }
                }
                try await Task.sleep(for: .milliseconds(250))
            }
            if denied {
                endBackground()
                // May suspend while locked. On return, validate the original value, not just UI state.
                while !UIApplication.shared.isProtectedDataAvailable {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(250))
                }
                try Task.checkCancellation()
                guard try await created.read(account: account) == tokens else { throw ProbeError.mismatch }
                outcome = "PASS: 잠금 중 읽기 차단 · 해제 후 동일 값 복구 · 더미 삭제 확인"
                #if targetEnvironment(simulator)
                outcome = "미확인: 시뮬레이터 결과는 실기기 잠금 보호 증빙으로 인정하지 않습니다."
                #endif
            }
        } catch is CancellationError {
            outcome = "중단됨: 잠금 보호 미판정"
        } catch TokenStoreError.status(let code) {
            outcome = "미확인: Keychain 오류 \(code)"
        } catch {
            outcome = "미확인: 진단 저장소 또는 값 검증 실패"
        }
        // Use an uncancelled task so cancellation cannot prevent dummy cleanup.
        if let store {
            let cleaned = await Task {
                do {
                    try await store.delete(account: account)
                    return try await store.read(account: account) == nil
                } catch { return false }
            }.value
            if !cleaned { outcome = "미확인: 더미 정리 실패. 잠금 해제 후 검증 시작을 다시 누르세요." }
            else if !outcome.hasPrefix("PASS") { outcome += " · 더미 정리 완료" }
        }
        status = outcome
        endBackground()
        task = nil
        running = false
    }

    private enum ProbeError: Error { case mismatch }
}
#endif
