/// User-initiated retries only. No automatic retry loop.
public struct PlaybackRetryBudget: Sendable {
    public let limit: Int
    public private(set) var used = 0
    public var remaining: Int { max(0, limit - used) }
    public init(limit: Int = 3) { self.limit = max(0, limit) }
    public mutating func consume() -> Bool {
        guard remaining > 0 else { return false }
        used += 1
        return true
    }
    public mutating func reset() { used = 0 }
}
