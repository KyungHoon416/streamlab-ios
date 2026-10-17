import Dispatch
import Network

/// Shared path observation for banners and session retry scheduling.
@MainActor public final class NetworkPathObserver {
    private var monitor: NWPathMonitor?
    private var generation = 0
    private let onChange: @MainActor @Sendable (Bool) -> Void

    public init(onChange: @escaping @MainActor @Sendable (Bool) -> Void) {
        self.onChange = onChange
    }

    public func start() {
        guard monitor == nil else { return }
        let ticket = generation
        let next = NWPathMonitor()
        monitor = next
        next.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket else { return }
                self.onChange(available)
            }
        }
        next.start(queue: DispatchQueue(label: "streamlab.network.path"))
    }

    public func stop() {
        generation &+= 1
        monitor?.cancel()
        monitor = nil
    }
    deinit { monitor?.cancel() }
}
