import Foundation

/// Deterministic observation reducer. The AVPlayer adapter owns effects; this value
/// validates its observations. Time is monotonic seconds injected by the caller.
public struct PlaybackDiagnostics: Sendable {
    public enum State: String, CaseIterable, Sendable {
        case idle, preparing, ready, playing, paused, buffering, seeking, ended, failed
    }
    public private(set) var state: State = .idle
    public private(set) var generation = 0
    public private(set) var firstFrameSeconds: Double?
    public private(set) var rebufferCount = 0
    public private(set) var rebufferSeconds: Double = 0
    public private(set) var failureCount = 0
    public private(set) var invalidTransitionCount = 0
    private var started: Double?
    private var lastTime: Double = 0
    private var bufferingStarted: Double?
    private var hasPlayed = false

    public init() {}

    public static func allows(_ from: State, _ to: State) -> Bool {
        if from == to { return true }
        if to == .idle { return true }
        if to == .failed { return from != .idle && from != .ended && from != .failed }
        switch from {
        case .idle: return to == .preparing
        case .preparing: return to == .ready
        case .ready: return [.playing, .paused, .seeking, .buffering].contains(to)
        case .playing: return [.paused, .buffering, .seeking, .ended].contains(to)
        case .paused: return [.playing, .buffering, .seeking, .ended].contains(to)
        case .buffering: return [.playing, .paused, .seeking, .ended].contains(to)
        case .seeking: return [.playing, .paused, .buffering, .ended].contains(to)
        case .ended: return to == .seeking
        case .failed: return false
        }
    }

    /// A new attempt (including retry) resets metrics and invalidates older callbacks.
    public mutating func begin(at time: Double) {
        guard time.isFinite, time >= 0 else { return }
        let ticket = generation + 1
        self = Self()
        generation = ticket
        started = time
        lastTime = time
        state = .preparing
    }

    @discardableResult
    public mutating func observe(_ next: State, at time: Double, generation ticket: Int) -> Bool {
        guard ticket == generation, time.isFinite, time >= lastTime else { return false }
        guard Self.allows(state, next) else {
            invalidTransitionCount += 1
            return false
        }
        lastTime = time
        guard next != state else { return true }
        if let start = bufferingStarted {
            rebufferSeconds += time - start
            bufferingStarted = nil
        }
        if next == .buffering && hasPlayed && state != .seeking {
            rebufferCount += 1
            bufferingStarted = time
        }
        if next == .playing { hasPlayed = true }
        if next == .failed { failureCount += 1 }
        state = next
        return true
    }

    /// First render-ready observation, not a physical display timestamp.
    public mutating func frameReady(at time: Double, generation ticket: Int) {
        guard ticket == generation, state != .idle, state != .failed,
              let started, firstFrameSeconds == nil, time.isFinite, time >= lastTime else { return }
        firstFrameSeconds = time - started
        lastTime = time
    }

    public mutating func finish(at time: Double) {
        _ = observe(.idle, at: time, generation: generation)
        generation += 1
    }
}
