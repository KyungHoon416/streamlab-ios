/// Per-item temporary subtitle selection. Automatic changes never become preferences.
public struct MuteCaptionPolicy: Sendable {
    private var previous: String?
    private var overridden = false
    public init() {}

    public mutating func userSelected(isMuted: Bool) {
        previous = nil
        overridden = isMuted
    }

    public mutating func update(isMuted: Bool, enabled: Bool, selected: String,
                                candidate: String?) -> String? {
        if !isMuted || !enabled {
            let restore = previous
            previous = nil
            if !isMuted { overridden = false }
            return restore
        }
        guard !overridden, previous == nil, selected == "off", let candidate else { return nil }
        previous = selected
        return candidate
    }
}
