import Combine
import Dispatch
import Network
import OSLog
import SwiftUI

/// Shared by the app root and presented players. A path is not a server reachability test.
@MainActor public final class NetworkConnectionStatus: ObservableObject {
    @Published public private(set) var connected: Bool?
    private var generation = 0
    private var monitor: NWPathMonitor?
    private let log = Logger(subsystem: "com.example.streamlab.demo", category: "NetworkStatus")

    public init() {}

    /// Owned by the root StateObject, never by a disappearing view's task.
    public func start(refresh: Bool = false) {
        guard monitor == nil || refresh else { return }
        generation &+= 1
        let ticket = generation
        monitor?.cancel()
        let next = NWPathMonitor()
        monitor = next
        log.notice("Network observation started, generation \(ticket)")
        next.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket else { return }
                self.connected = available
                self.log.notice("Network path available: \(available), generation \(ticket)")
            }
        }
        next.start(queue: DispatchQueue(label: "streamlab.network"))
    }

    deinit { monitor?.cancel() }

}

@MainActor public struct NetworkConnectionBanner: View {
    @EnvironmentObject private var network: NetworkConnectionStatus

    public init() {}

    public var body: some View {
        if network.connected == false {
            Label("네트워크 연결이 끊겼습니다. 연결 상태를 확인해주세요.", systemImage: "wifi.slash")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(Color.red.opacity(0.9))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("network-connection-banner")
        }
    }
}
