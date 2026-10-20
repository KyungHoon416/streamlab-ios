/// A path hint, not proof that a remote server is reachable. Never gates playback.
public struct NetworkConnectionNotice: Sendable {
    public enum Display: Equatable, Sendable { case none, offline, restored }
    public private(set) var display: Display = .none
    private var previous: Bool?
    public init() {}
    public mutating func receive(available: Bool) {
        let old = previous
        previous = available
        if !available { display = .offline }
        else if old == false { display = .restored }
    }
    public mutating func dismissRestored() {
        if display == .restored { display = .none }
    }
}
