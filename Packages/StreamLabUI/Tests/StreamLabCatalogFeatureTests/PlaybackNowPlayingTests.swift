import Foundation
import MediaPlayer
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackNowPlayingTests: XCTestCase {
    @MainActor
    func testEndClearsMetadataAndDisablesOwnedCommands() {
        let service = PlaybackNowPlaying()
        let owner = UUID()
        service.begin(owner: owner, title: "First", subtitle: "Fixture", artworkURL: nil) { _ in }
        service.update(owner: owner, position: 12, duration: 100, rate: 1, canSeek: true)
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        service.end(owner: owner)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.skipBackwardCommand, center.skipForwardCommand,
                        center.changePlaybackPositionCommand] as [MPRemoteCommand] {
            XCTAssertFalse(command.isEnabled)
        }
        service.end(owner: owner) // SwiftUI disappearance may repeat explicit close.
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    @MainActor
    func testLateOldCleanupCannotClearNewPresentation() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        defer { service.end(owner: current) }
        service.begin(owner: old, title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.begin(owner: current, title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 20, duration: 100, rate: 1, canSeek: true)
        service.end(owner: old)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Second")
        XCTAssertTrue(MPRemoteCommandCenter.shared().playCommand.isEnabled)
    }

    @MainActor
    func testLateOldSampleCannotOverwriteNewProgress() {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        defer { service.end(owner: current) }
        service.begin(owner: old, title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.begin(owner: current, title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 20, duration: 100, rate: 1, canSeek: true)
        service.update(owner: old, position: 90, duration: 200, rate: 0, canSeek: false)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 20)
        XCTAssertTrue(MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled)
    }

    @MainActor
    func testQueuedCommandIsRejectedAfterCloseOrOwnerReplacement() async {
        let service = PlaybackNowPlaying()
        let old = UUID(), current = UUID()
        var oldCalls = 0, currentCalls = 0
        defer { service.end(owner: current) }
        service.begin(owner: old, title: "First", subtitle: "", artworkURL: nil) { _ in oldCalls += 1 }
        // Queue on MainActor, then replace the presentation without yielding.
        let queued = Task { @MainActor in service.deliver(.play, owner: old) }
        service.end(owner: old)
        service.deliver(.pause, owner: old)
        service.begin(owner: current, title: "Second", subtitle: "", artworkURL: nil) { _ in currentCalls += 1 }
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
        service.begin(owner: old, title: "First", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: old, position: 0, duration: 100, rate: 0, canSeek: true)
        service.begin(owner: current, title: "Second", subtitle: "", artworkURL: nil) { _ in }
        service.update(owner: current, position: 0, duration: 100, rate: 0, canSeek: true)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Second")
    }
}
