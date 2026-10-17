import Foundation
import MediaPlayer
import UIKit

/// Process-wide system UI, owned by exactly one player generation at a time.
@MainActor final class PlaybackNowPlaying {
    static let shared = PlaybackNowPlaying()
    enum Action: Sendable { case play, pause, toggle, skip(Double), seek(Double) }
    private var owner: UUID?
    private var targets: [(MPRemoteCommand, Any)] = []
    private var metadata: [String: Any] = [:]
    private struct Snapshot: Equatable {
        let second: Int
        let duration: Double
        let rate: Double
        let canSeek: Bool
    }
    private var lastSnapshot: Snapshot?
    private var action: (@MainActor (Action) -> Void)?

    func begin(owner: UUID, title: String, subtitle: String, artworkURL: URL?,
               action: @escaping @MainActor (Action) -> Void) {
        if let old = self.owner { end(owner: old) }
        self.owner = owner
        self.action = action
        metadata = [MPMediaItemPropertyTitle: title, MPMediaItemPropertyArtist: subtitle,
                    MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
                    MPNowPlayingInfoPropertyIsLiveStream: false]
        if let artworkURL, artworkURL.isFileURL, let image = UIImage(contentsOfFile: artworkURL.path) {
            // MediaPlayer may request artwork on a background queue. Explicit Sendable
            // prevents this closure from inheriting begin()'s MainActor isolation.
            let request: @Sendable (CGSize) -> UIImage = { _ in image }
            metadata[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size, requestHandler: request)
        }
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipForwardCommand.preferredIntervals = [10]
        bind(center.playCommand, owner: owner) { _ in .play }
        bind(center.pauseCommand, owner: owner) { _ in .pause }
        bind(center.togglePlayPauseCommand, owner: owner) { _ in .toggle }
        bind(center.skipBackwardCommand, owner: owner) { _ in .skip(-10) }
        bind(center.skipForwardCommand, owner: owner) { _ in .skip(10) }
        bind(center.changePlaybackPositionCommand, owner: owner) { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent,
                  event.positionTime.isFinite else { return nil }
            return .seek(event.positionTime)
        }
    }

    private func bind(_ command: MPRemoteCommand, owner: UUID,
                      decode: @escaping @Sendable (MPRemoteCommandEvent) -> Action?) {
        command.isEnabled = true
        // This callback also belongs to MediaPlayer, not to the MainActor executor.
        let handler: @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] event in
            guard let action = decode(event) else { return .commandFailed }
            // Do not transfer MediaPlayer events across executors, only the value action.
            Task { @MainActor [weak self] in
                guard let self, self.owner == owner else { return }
                self.action?(action)
            }
            return .success
        }
        let target = command.addTarget(handler: handler)
        targets.append((command, target))
    }

    func update(owner: UUID, position: Double, duration: Double, rate: Double, canSeek: Bool) {
        guard self.owner == owner else { return }
        let snapshot = Snapshot(second: Int(exactly: position.rounded(.down)) ?? 0,
                                duration: duration, rate: rate, canSeek: canSeek)
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        var info = metadata
        info[MPMediaItemPropertyPlaybackDuration] = duration.isFinite ? max(0, duration) : 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position.isFinite ? max(0, position) : 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate.isFinite ? max(0, rate) : 0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        let center = MPRemoteCommandCenter.shared()
        center.skipBackwardCommand.isEnabled = canSeek
        center.skipForwardCommand.isEnabled = canSeek
        center.changePlaybackPositionCommand.isEnabled = canSeek
    }

    func end(owner: UUID) {
        guard self.owner == owner else { return }
        for (command, target) in targets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        targets.removeAll()
        action = nil
        metadata.removeAll()
        lastSnapshot = nil
        self.owner = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
