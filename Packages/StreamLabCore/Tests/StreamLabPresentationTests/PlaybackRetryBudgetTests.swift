import XCTest
import StreamLabDomain

final class PlaybackRetryBudgetTests: XCTestCase {
    func testRetriesAreBoundedAndDoNotReopenAfterExhaustion() {
        var budget = PlaybackRetryBudget()
        for remaining in [2, 1, 0] {
            XCTAssertTrue(budget.consume())
            XCTAssertEqual(budget.remaining, remaining)
        }
        for _ in 0..<100 { XCTAssertFalse(budget.consume()) }
        XCTAssertEqual(budget.used, 3)
    }
    func testExplicitNewPresentationCanResetBudget() {
        var budget = PlaybackRetryBudget(limit: 1)
        XCTAssertTrue(budget.consume())
        XCTAssertFalse(budget.consume())
        budget.reset()
        XCTAssertTrue(budget.consume())
    }
    func testInvalidLimitCannotProduceRetries() {
        var budget = PlaybackRetryBudget(limit: -1)
        XCTAssertEqual(budget.remaining, 0)
        XCTAssertFalse(budget.consume())
    }
}
