/// Coalesces connection recovery events within one active profile session.
/// A satisfied path is a retry opportunity, not proof that a server is reachable.
@MainActor public final class ConnectionRecoveryCoordinator {
    private let synchronize: @MainActor @Sendable () async -> Void
    private var available: Bool?
    private var pending = false
    private var active = true
    private var generation = 0
    private var task: Task<Void, Never>?

    public init(synchronize: @escaping @MainActor @Sendable () async -> Void) {
        self.synchronize = synchronize
    }

    public func update(isAvailable: Bool) {
        guard active else { return }
        let previous = available
        available = isAvailable
        guard isAvailable, previous != true else { return }
        pending = true
        guard task == nil else { return }
        let ticket = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == ticket { self.task = nil } }
            while self.active, self.generation == ticket, self.pending, !Task.isCancelled {
                self.pending = false
                guard self.available == true else { return }
                await self.synchronize()
            }
        }
    }

    public func suspend() {
        generation &+= 1
        active = false
        available = nil
        pending = false
        task?.cancel()
        task = nil
    }

    public func resume() { active = true }
    public func waitForIdle() async { await task?.value }
    deinit { task?.cancel() }
}
