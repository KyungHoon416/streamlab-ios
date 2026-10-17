import Combine
import StreamLabDesignSystem
import SwiftUI

/// Scoped to the profile screen. Never controls catalog requests or playback.
@MainActor private final class ProfileNetworkStatus: ObservableObject {
    @Published private(set) var offline = false
    private var observer: NetworkPathObserver?

    func start() {
        stop()
        offline = false
        let observer = NetworkPathObserver { [weak self] available in
            self?.offline = !available
        }
        self.observer = observer
        observer.start()
    }

    func stop() {
        observer?.stop()
        observer = nil
    }

}

@MainActor public struct ProfileNetworkBanner: View {
    @StateObject private var network = ProfileNetworkStatus()
    @Environment(\.scenePhase) private var phase

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            if network.offline {
                Label("네트워크 연결이 없습니다. 저장된 콘텐츠는 이용할 수 있습니다.", systemImage: "wifi.slash")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(Color.red.opacity(0.9))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile-network-banner")
            }
        }
        .onAppear { network.start() }
        .onDisappear { network.stop() }
        .onChange(of: phase) { _, value in
            if value == .active { network.start() }
        }
    }
}
