import Combine
import Dispatch
import Network
import SwiftUI

/// Shared by the app root and presented players. A path is not a server reachability test.
@MainActor public final class NetworkConnectionStatus: ObservableObject {
    @Published public private(set) var connected: Bool?
    private var generation = 0

    public init() {}

    public func observe(active: Bool) async {
        generation &+= 1
        let ticket = generation
        guard active, !Task.isCancelled else { return }
        let monitor = NWPathMonitor()
        let (updates, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        monitor.pathUpdateHandler = { path in
            continuation.yield(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "streamlab.network"))
        defer {
            monitor.cancel()
            continuation.finish()
        }
        // Cancellation ends the stream iteration; a new foreground task gets a fresh path.
        for await available in updates {
            guard !Task.isCancelled, generation == ticket else { return }
            connected = available
        }
    }
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
