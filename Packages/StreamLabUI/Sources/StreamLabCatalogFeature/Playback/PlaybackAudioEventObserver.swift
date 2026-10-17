import AVFoundation
import Foundation

enum PlaybackAudioEvent: Sendable {
    case interruptionBegan(preventsAutomaticResume: Bool)
    case interruptionEnded(shouldResume: Bool)
    case outputDisconnected
}

/// Immutable observer tokens; only Sendable values leave the notification callbacks.
final class PlaybackAudioEventObserver: @unchecked Sendable {
    private let tokens: [NSObjectProtocol]

    init(handler: @escaping @Sendable (PlaybackAudioEvent) -> Void) {
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began:
                    // Missing reason retains legacy ordinary-interruption behavior.
                    // Explicit non-default reasons (including unknown future ones) require
                    // a user play action rather than automatic resumption.
                    let reason = (note.userInfo?[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.uintValue
                    let preventsResume = reason.map { $0 != AVAudioSession.InterruptionReason.default.rawValue } ?? false
                    handler(.interruptionBegan(preventsAutomaticResume: preventsResume))
                case .ended:
                    let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    handler(.interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)))
                @unknown default: break
                }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
                guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                handler(.outputDisconnected)
            }
        ]
    }

    deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}
