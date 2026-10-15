import AVFoundation
import Foundation
import OSLog

/// The system audio session is process-wide. All mutations are FIFO on this queue.
/// Safety: `owner` is accessed only inside `queue` blocks; other fields are immutable.
/// No AVFoundation object crosses the queue boundary.
final class PlaybackAudioSession: @unchecked Sendable {
    static let shared = PlaybackAudioSession()
    private let queue = DispatchQueue(label: "com.example.streamlab.audio-session", qos: .userInitiated)
    private let log = Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackAudioSession")
    private var owner: UUID?

    private init() {}

    func activate(owner token: UUID, completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            dispatchPrecondition(condition: .notOnQueue(.main))
            owner = token
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback)
                try session.setActive(true)
                completion(true)
            } catch {
                // Keep ownership until release so a partially activated session is cleaned up.
                log.error("audio_session_activation_failed")
                completion(false)
            }
        }
    }

    func release(owner token: UUID) {
        queue.async { [self] in
            dispatchPrecondition(condition: .notOnQueue(.main))
            guard owner == token else { return }
            owner = nil
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                log.error("audio_session_deactivation_failed")
            }
        }
    }
}
