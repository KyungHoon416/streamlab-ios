import Foundation

/// A sample is taken before playback and after every fifth dismissed player.
public struct PlaybackMemoryRun: Sendable {
    public let baseline: UInt64
    public private(set) var closed = 0
    public private(set) var checkpoints: [UInt64] = []
    public var finished: Bool { closed == 20 && checkpoints.count == 4 }
    public var awaitingSample: Bool { closed / 5 > checkpoints.count }

    public init(baseline: UInt64) { self.baseline = baseline }

    public mutating func close(played: Bool) {
        if played && !awaitingSample && closed < 20 { closed += 1 }
    }

    public mutating func sample(_ bytes: UInt64) {
        if awaitingSample { checkpoints.append(bytes) }
    }
}
