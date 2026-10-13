import XCTest
import StreamLabDomain

final class AutoAdvanceCountdownTests: XCTestCase {
    func testDeadlineFiresExactlyOnce() {
        var countdown = AutoAdvanceCountdown()
        countdown.start()
        XCTAssertEqual(countdown.remaining, 10)
        XCTAssertFalse(countdown.advance(elapsed: 9.9))
        XCTAssertEqual(countdown.remaining, 1)
        XCTAssertTrue(countdown.advance(elapsed: 10))
        XCTAssertFalse(countdown.advance(elapsed: 11))
        XCTAssertNil(countdown.remaining)
    }

    func testCancellationCannotRestartForSameItem() {
        var countdown = AutoAdvanceCountdown()
        countdown.start()
        countdown.cancel()
        countdown.start()
        XCTAssertFalse(countdown.advance(elapsed: 100))
        XCTAssertEqual(countdown.state, .cancelled)
        countdown.reset()
        countdown.start()
        XCTAssertTrue(countdown.advance(elapsed: 10))
    }

    func testInvalidElapsedDoesNotAdvance() {
        var countdown = AutoAdvanceCountdown()
        countdown.start()
        for elapsed in [Double.nan, Double.infinity, -1] {
            XCTAssertFalse(countdown.advance(elapsed: elapsed))
            XCTAssertEqual(countdown.remaining, 10)
        }
    }
}
