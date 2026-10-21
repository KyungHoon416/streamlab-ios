import Combine
import StreamLabDomain
import SwiftUI

@MainActor private final class NetworkBannerStatus: ObservableObject {
    static let shared = NetworkBannerStatus()
    private var consumers = 0
    private var replay: Task<Void, Never>?
    @Published private(set) var notice = NetworkConnectionNotice()
    private var observer: NetworkPathObserver?
    private var dismissal: Task<Void, Never>?

    func start() {
        consumers += 1
        guard observer == nil else { return }
        let observer = NetworkPathObserver { [weak self] available in self?.receive(available) }
        self.observer = observer
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-network-recovery") {
            // Deterministic path events only; never changes OS connectivity or media.
            replay = Task { [weak self] in
                self?.receive(true)
                do { try await Task.sleep(for: .seconds(ProcessInfo.processInfo.arguments.contains("--ui-test-network-screen") ? 30 : 8)) } catch { return }
                self?.receive(false)
                do { try await Task.sleep(for: .seconds(6)) } catch { return }
                self?.receive(true)
            }
            return
        }
        #endif
        observer.start()
    }
    private func receive(_ available: Bool) {
        let old = notice.display
        notice.receive(available: available)
        guard notice.display != old else { return }
        dismissal?.cancel()
        if notice.display == .restored {
            dismissal = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                self?.notice.dismissRestored()
            }
        }
    }
    func stop() {
        consumers = max(0, consumers - 1)
        guard consumers == 0 else { return }
        replay?.cancel(); replay = nil
        observer?.stop(); observer = nil
        dismissal?.cancel(); dismissal = nil
        notice.dismissRestored()
    }
    deinit { dismissal?.cancel(); replay?.cancel() }
}

/// Root and full-screen player share one observer and recovery timer.
@MainActor public struct NetworkConnectionBanner: View {
    @ObservedObject private var network = NetworkBannerStatus.shared
    @Environment(\.streamLabContrast) private var contrast
    private let showOffline: Bool
    public init(showOffline: Bool) { self.showOffline = showOffline }

    public var body: some View {
        VStack(spacing: 0) {
            if network.notice.display == .restored {
                banner("네트워크에 다시 연결되었습니다.", symbol: "wifi", color: .green)
                    .accessibilityIdentifier("network-reconnected-banner")
            } else if showOffline && network.notice.display == .offline {
                banner("네트워크 연결이 없습니다. 저장된 콘텐츠는 이용할 수 있습니다.", symbol: "wifi.slash", color: .red)
                    .accessibilityIdentifier("profile-network-banner")
            }
        }
        .onAppear { network.start() }
        .onDisappear { network.stop() }
    }
    private func banner(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .foregroundStyle(.white).background(contrast == .increased ? Color.black : color.opacity(0.9))
            .overlay(Rectangle().stroke(.white, lineWidth: contrast == .increased ? 1 : 0))
            .accessibilityElement(children: .combine)
    }
}
