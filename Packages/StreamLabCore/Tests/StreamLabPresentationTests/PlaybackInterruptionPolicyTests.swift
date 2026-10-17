import XCTest
import StreamLabDomain

final class PlaybackInterruptionPolicyTests: XCTestCase {
    func testPlayingResumesOnlyWithSystemPermission() {
        var policy = PlaybackInterruptionPolicy()
        policy.begin(wantsPlayback: true)
        XCTAssertTrue(policy.isInterrupted)
        XCTAssertTrue(policy.end(shouldResume: true))
        XCTAssertFalse(policy.isInterrupted)
        policy.begin(wantsPlayback: true)
        XCTAssertFalse(policy.end(shouldResume: false))
    }

    func testPreviouslyPausedPlaybackStaysPaused() {
        var policy = PlaybackInterruptionPolicy()
        policy.begin(wantsPlayback: false)
        XCTAssertFalse(policy.end(shouldResume: true))
    }

    func testManualPauseOrDisconnectedOutputCancelsResume() {
        var policy = PlaybackInterruptionPolicy()
        policy.begin(wantsPlayback: true)
        policy.cancelResume()
        XCTAssertFalse(policy.end(shouldResume: true))
    }

    func testRepeatedBeginDoesNotLoseOriginalIntent() {
        var policy = PlaybackInterruptionPolicy()
        policy.begin(wantsPlayback: true)
        policy.begin(wantsPlayback: false)
        XCTAssertTrue(policy.end(shouldResume: true))
    }

    func testRepeatedBeginCannotUndoManualPause() {
        var policy = PlaybackInterruptionPolicy()
        policy.begin(wantsPlayback: true)
        policy.cancelResume()
        policy.begin(wantsPlayback: true)
        XCTAssertFalse(policy.end(shouldResume: true))
    }

    func testSuspensionAndUnmatchedEndNeverResume() {
        var policy = PlaybackInterruptionPolicy()
        XCTAssertFalse(policy.end(shouldResume: true))
        policy.begin(wantsPlayback: true, preventsAutomaticResume: true)
        XCTAssertFalse(policy.end(shouldResume: true))
        policy.begin(wantsPlayback: true)
        XCTAssertTrue(policy.end(shouldResume: true))
        XCTAssertFalse(policy.end(shouldResume: true))
    }
}
