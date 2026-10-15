import Combine
import Dispatch
import Network

/// Path availability is advisory: it does not prove that the HLS server is reachable.
@MainActor final class PlaybackNetworkStatus: ObservableObject {
    @Published private(set) var connected: Bool?
    @Published private(set) var recovered = false
    private var generation = 0

    func observe(enabled: Bool) async {
        generation &+= 1
        let ticket = generation
        connected = nil
        recovered = false
        guard enabled, !Task.isCancelled else { return }

        let monitor = NWPathMonitor()
        let (updates, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        // Only a Sendable value crosses from the Network queue to the main actor.
        monitor.pathUpdateHandler = { path in
            continuation.yield(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "streamlab.playback.network"))
        defer {
            monitor.cancel()
            continuation.finish()
        }
        for await available in updates {
            guard !Task.isCancelled, generation == ticket else { return }
            if connected == false && available { recovered = true }
            if !available { recovered = false }
            connected = available
        }
    }

    func clearRecovery() { recovered = false }
}
