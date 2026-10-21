import Foundation
import AVFoundation
import MediaPlayer
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackNowPlayingTests: XCTestCase {
    @MainActor func testSessionOwnsExactPlayerAndReplacementCleansOldCenter() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        let first = AVPlayer(), second = AVPlayer()
        service.begin(owner: old, player: first, title: "First", subtitle: "", artworkURL: nil) { _ in }
        let oldSession = service.session!
        XCTAssertTrue(oldSession.players.first === first)
        service.update(owner: old, position: 0, duration: 30, rate: 1, canSeek: true)
        service.begin(owner: current, player: second, title: "Second", subtitle: "", artworkURL: nil) { _ in }
        defer { service.end(owner: current) }
        XCTAssertTrue(service.session!.players.first === second)
        XCTAssertFalse(service.session === oldSession)
        XCTAssertNil(oldSession.nowPlayingInfoCenter.nowPlayingInfo)
        XCTAssertFalse(oldSession.remoteCommandCenter.pauseCommand.isEnabled)
        XCTAssertTrue(service.session!.remoteCommandCenter.pauseCommand.isEnabled)
    }

    @MainActor
    func testEndClearsMetadataAndDisablesOwnedCommands() {
        let service = PlaybackNowPlaying()
        let owner = UUID()
        service.begin(owner: owner, player: AVPlayer(), title: "First", subtitle: "Fixture", artworkURL: nil) { _ in }
        service.update(owner: owner, position: 12, duration: 100, rate: 1, canSeek: true)
        XCTAssertNotNil(service.session?.nowPlayingInfoCenter.nowPlayingInfo)
        let endedSession = service.session!
        service.end(owner: owner)
        XCTAssertNil(endedSession.nowPlayingInfoCenter.nowPlayingInfo)
        XCTAssertNil(service.session)
        let center = endedSession.remoteCommandCenter
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.skipBackwardCommand, center.skipForwardCommand,
                        center.changePlaybackPositionCommand] as [MPRemoteCommand] {
            XCTAssertFalse(command.isEnabled)
        }
        service.end(owner: owner) // SwiftUI disappearance may repeat explicit close.
        XCTAssertNil(service.session?.nowPlayingInfoCenter.nowPlayingInfo)
    }

    @MainActor
    func testLateOldCleanupCannotClearNewPresentation() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        defer { service.end(owner: current) }
        service.begin(owner: old, player: AVPlayer(), title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.begin(owner: current, player: AVPlayer(), title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 20, duration: 100, rate: 1, canSeek: true)
        service.end(owner: old)
        XCTAssertEqual(service.session?.nowPlayingInfoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Second")
        XCTAssertTrue(service.session!.remoteCommandCenter.playCommand.isEnabled)
    }

    @MainActor
    func testLateOldSampleCannotOverwriteNewProgress() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        defer { service.end(owner: current) }
        service.begin(owner: old, player: AVPlayer(), title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.begin(owner: current, player: AVPlayer(), title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 20, duration: 100, rate: 1, canSeek: true)
        service.update(owner: old, position: 90, duration: 200, rate: 0, canSeek: false)
        XCTAssertEqual(service.session?.nowPlayingInfoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 20)
        XCTAssertTrue(service.session!.remoteCommandCenter.skipForwardCommand.isEnabled)
    }

    @MainActor
    func testQueuedCommandIsRejectedAfterCloseOrOwnerReplacement() async {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        var oldCalls = 0, currentCalls = 0
        defer { service.end(owner: current) }
        service.begin(owner: old, player: AVPlayer(), title: "First", subtitle: "", artworkURL: nil) { _ in oldCalls += 1 }
        // Queue on MainActor, then replace the presentation without yielding.
        let queued = Task { @MainActor in service.deliver(.play, owner: old) }
        service.end(owner: old)
        service.deliver(.pause, owner: old)
        service.begin(owner: current, player: AVPlayer(), title: "Second", subtitle: "", artworkURL: nil) { _ in currentCalls += 1 }
        await queued.value
        XCTAssertEqual(oldCalls, 0)
        XCTAssertEqual(currentCalls, 0)
        service.deliver(.skip(10), owner: current)
        XCTAssertEqual(currentCalls, 1)
    }

    @MainActor
    func testNewPresentationPublishesEvenWithIdenticalPlaybackSnapshot() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        defer { service.end(owner: current) }
        service.begin(owner: old, player: AVPlayer(), title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: old, position: 0, duration: 100, rate: 0, canSeek: true)
        service.begin(owner: current, player: AVPlayer(), title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 0, duration: 100, rate: 0, canSeek: true)
        XCTAssertEqual(service.session?.nowPlayingInfoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Second")
    }
}
