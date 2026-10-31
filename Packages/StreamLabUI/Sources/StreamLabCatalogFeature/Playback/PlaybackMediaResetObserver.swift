import AVFoundation
import Foundation

/// Immutable observer token. NotificationCenter supports removal from any thread.
/// No notification payload or AVFoundation object is transferred to another actor.
final class PlaybackMediaResetObserver: @unchecked Sendable {
    private let token: NSObjectProtocol
    init(handler: @escaping @Sendable () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main
        ) { _ in handler() }
    }
    deinit { NotificationCenter.default.removeObserver(token) }
}

/// Filters by the exact item. The payload never crosses an actor boundary.
/// Immutable token ownership permits removal during nonisolated deinitialization.
final class PlaybackItemEndObserver: @unchecked Sendable {
    private let token: NSObjectProtocol
    private let failureToken: NSObjectProtocol
    init(item: AVPlayerItem, failure: @escaping @Sendable () -> Void, handler: @escaping @Sendable () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item, queue: .main
        ) { _ in handler() }
        failureToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item, queue: .main
        ) { _ in failure() }
    }
    deinit {
        NotificationCenter.default.removeObserver(token)
        NotificationCenter.default.removeObserver(failureToken)
    }
}
