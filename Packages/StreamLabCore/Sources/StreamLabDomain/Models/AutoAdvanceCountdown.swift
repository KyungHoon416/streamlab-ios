import Foundation

/// Caller supplies elapsed monotonic time; no timer or task is owned here.
public struct AutoAdvanceCountdown: Equatable, Sendable {
    public enum State: Equatable, Sendable { case idle, waiting, cancelled, consumed }
    public private(set) var state: State = .idle
    public private(set) var remaining: Int?
    public init() {}

    public mutating func start() {
        guard state == .idle else { return }
        state = .waiting
        remaining = 10
    }

    /// Returns true at most once for a playback item.
    public mutating func advance(elapsed: Double) -> Bool {
        guard state == .waiting, elapsed.isFinite, elapsed >= 0 else { return false }
        if elapsed >= 10 {
            state = .consumed
            remaining = nil
            return true
        }
        remaining = Int(ceil(10 - elapsed))
        return false
    }

    public mutating func cancel() {
        state = .cancelled
        remaining = nil
    }

    public mutating func reset() { self = Self() }
}
