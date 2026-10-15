import XCTest
import StreamLabDomain

final class PlaybackDiagnosticsTests: XCTestCase {
    func testInitialWaitSeekPauseAndDuplicateEventsAreNotRebuffers() {
        var d = PlaybackDiagnostics()
        d.begin(at: 10)
        let g = d.generation
        XCTAssertTrue(d.observe(.ready, at: 11, generation: g))
        XCTAssertTrue(d.observe(.buffering, at: 12, generation: g))
        XCTAssertEqual(d.rebufferCount, 0)
        XCTAssertTrue(d.observe(.playing, at: 13, generation: g))
        d.frameReady(at: 13.25, generation: g)
        d.frameReady(at: 14, generation: g)
        XCTAssertEqual(d.firstFrameSeconds, 3.25)
        XCTAssertTrue(d.observe(.seeking, at: 15, generation: g))
        XCTAssertTrue(d.observe(.buffering, at: 17, generation: g))
        XCTAssertTrue(d.observe(.paused, at: 18, generation: g))
        XCTAssertEqual(d.rebufferCount, 0)
        XCTAssertTrue(d.observe(.playing, at: 20, generation: g))
        XCTAssertTrue(d.observe(.buffering, at: 21, generation: g))
        XCTAssertTrue(d.observe(.buffering, at: 22, generation: g))
        XCTAssertTrue(d.observe(.playing, at: 24, generation: g))
        XCTAssertEqual(d.rebufferCount, 1)
        XCTAssertEqual(d.rebufferSeconds, 3)
    }

    func testFailureAndCancellationCloseOpenIntervalAndRejectStaleCallbacks() {
        var d = PlaybackDiagnostics()
        d.begin(at: 0)
        let g = d.generation
        _ = d.observe(.ready, at: 1, generation: g)
        _ = d.observe(.playing, at: 2, generation: g)
        _ = d.observe(.buffering, at: 3, generation: g)
        _ = d.observe(.failed, at: 7, generation: g)
        _ = d.observe(.failed, at: 8, generation: g)
        XCTAssertEqual(d.failureCount, 1)
        XCTAssertEqual(d.rebufferSeconds, 4)
        d.finish(at: 9)
        XCTAssertFalse(d.observe(.playing, at: 10, generation: g))
        d.begin(at: 11)
        d.frameReady(at: 12, generation: g)
        XCTAssertNil(d.firstFrameSeconds)
        XCTAssertEqual(d.failureCount, 0)
    }

    func testInvalidTransitionAndInvalidClockDoNotMutateState() {
        var d = PlaybackDiagnostics()
        d.begin(at: 5)
        let g = d.generation
        XCTAssertFalse(d.observe(.playing, at: 6, generation: g))
        XCTAssertEqual(d.invalidTransitionCount, 1)
        for time in [Double.nan, Double.infinity, 4] {
            XCTAssertFalse(d.observe(.ready, at: time, generation: g))
        }
        XCTAssertEqual(d.state, .preparing)
        XCTAssertTrue(d.observe(.ready, at: 7, generation: g))
    }

    func testCancelDuringBufferingAndRepeatedFinish() {
        var d = PlaybackDiagnostics()
        d.begin(at: 0)
        let g = d.generation
        _ = d.observe(.ready, at: 1, generation: g)
        _ = d.observe(.playing, at: 2, generation: g)
        _ = d.observe(.buffering, at: 3, generation: g)
        d.finish(at: 5)
        d.finish(at: 10)
        XCTAssertEqual(d.rebufferCount, 1)
        XCTAssertEqual(d.rebufferSeconds, 2)
        XCTAssertEqual(d.state, .idle)
        XCTAssertFalse(d.observe(.playing, at: 11, generation: g))
    }

    func testTransitionMatrix() {
        // Independent explicit contract; all 81 pairs, including duplicates and cancellation.
        let permitted: [PlaybackDiagnostics.State: Set<PlaybackDiagnostics.State>] = [
            .idle: [.idle, .preparing],
            .preparing: [.preparing, .ready, .failed, .idle],
            .ready: [.ready, .playing, .paused, .seeking, .buffering, .failed, .idle],
            .playing: [.playing, .paused, .buffering, .seeking, .ended, .failed, .idle],
            .paused: [.paused, .playing, .buffering, .seeking, .ended, .failed, .idle],
            .buffering: [.buffering, .playing, .paused, .seeking, .ended, .failed, .idle],
            .seeking: [.seeking, .playing, .paused, .buffering, .ended, .failed, .idle],
            .ended: [.ended, .seeking, .idle],
            .failed: [.failed, .idle]
        ]
        for from in PlaybackDiagnostics.State.allCases {
            for to in PlaybackDiagnostics.State.allCases {
                XCTAssertEqual(PlaybackDiagnostics.allows(from, to), permitted[from]!.contains(to), "\(from) -> \(to)")
            }
        }
    }
}
