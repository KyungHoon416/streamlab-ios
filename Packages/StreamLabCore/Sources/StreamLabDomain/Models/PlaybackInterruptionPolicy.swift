/// Playback intent survives an interruption only until an explicit cancellation.
public struct PlaybackInterruptionPolicy: Sendable {
    public private(set) var isInterrupted = false
    private var resumeRequested = false
    public init() {}

    public mutating func begin(wantsPlayback: Bool, preventsAutomaticResume: Bool = false) {
        if !isInterrupted { resumeRequested = wantsPlayback }
        isInterrupted = true
        if preventsAutomaticResume { resumeRequested = false }
    }

    public mutating func cancelResume() { resumeRequested = false }

    public mutating func end(shouldResume: Bool) -> Bool {
        let resume = isInterrupted && resumeRequested && shouldResume
        isInterrupted = false
        resumeRequested = false
        return resume
    }
}
