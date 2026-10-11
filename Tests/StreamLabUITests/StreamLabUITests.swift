import XCTest

@MainActor final class StreamLabUITests: XCTestCase {
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if largeText { app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    private func choose(_ id: String, in app: XCUIApplication) {
        let profile = app.buttons["profile-\(id)"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        profile.tap()
        XCTAssertTrue(app.collectionViews["home-catalog"].cells.firstMatch.waitForExistence(timeout: 5))
    }
    func testColdLaunchAndRelaunchShowProfiles() {
        let app = XCUIApplication()
        for _ in 0..<2 {
            app.launch()
            for id in ["adult-a", "adult-b", "kids-a"] {
                let button = app.buttons["profile-\(id)"]
                XCTAssertTrue(button.waitForExistence(timeout: 10), "Profile root must be installed after launch")
                XCTAssertTrue(button.isHittable, "Profile button must be visible and tappable")
            }
            app.terminate()
        }
    }

    func testStoryboardScenesAndPhase2Notice() {
        let app = launch()
        choose("adult-a", in: app)
        app.collectionViews["home-catalog"].cells.firstMatch.tap()
        let playback = app.buttons["phase2-playback"]
        XCTAssertTrue(playback.waitForExistence(timeout: 5))
        playback.tap()
        XCTAssertTrue(app.alerts["Phase 2 예정"].waitForExistence(timeout: 2))
        app.alerts.buttons["확인"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["switch-profile"].tap()
        choose("adult-b", in: app)
    }
    func testSearchPaginationAndProfileSwitch() {
        let app = launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        let table = app.tables["search-results"]
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(table.cells.count, 24)
        app.buttons["load-more"].tap()
        let loaded = NSPredicate(format: "count == 48")
        expectation(for: loaded, evaluatedWith: table.cells)
        waitForExpectations(timeout: 5)
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("액션")
        app.buttons["switch-profile"].tap()
        choose("kids-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "제목 또는 장르 검색")
        for cell in table.cells.allElementsBoundByIndex {
            XCTAssertFalse(cell.label.contains("19+"))
            XCTAssertFalse(cell.label.contains("15+"))
            XCTAssertFalse(cell.label.contains("12+"))
        }
    }
    func testSearchPagesSurviveDetailAndTabNavigation() {
        let app = launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        let table = app.tables["search-results"]
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 5))
        app.buttons["load-more"].tap()
        expectation(for: NSPredicate(format: "count == 48"), evaluatedWith: table.cells)
        waitForExpectations(timeout: 5)
        let firstID = table.cells.firstMatch.identifier
        table.cells.firstMatch.tap()
        XCTAssertTrue(app.buttons["phase2-playback"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        XCTAssertEqual(table.cells.count, 48)
        XCTAssertEqual(table.cells.firstMatch.identifier, firstID)
        app.tabBars.buttons["홈"].tap()
        app.tabBars.buttons["검색"].tap()
        XCTAssertEqual(table.cells.count, 48)
    }

    func testPaginationOverlayAppearsAndClears() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-slow-catalog"]
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        let table = app.tables["search-results"]
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 8))
        let more = app.buttons["load-more"]
        more.tap()
        let loading = app.staticTexts["pagination-loading-label"]
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        XCTAssertFalse(more.isEnabled)
        expectation(for: NSPredicate(format: "count == 48"), evaluatedWith: table.cells)
        waitForExpectations(timeout: 8)
        XCTAssertFalse(loading.exists)
        XCTAssertTrue(more.isEnabled)
    }

    func testProfileSwitchDuringPaginationRemovesOverlayAndOldResults() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-slow-catalog"]
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        let table = app.tables["search-results"]
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 8))
        app.buttons["load-more"].tap()
        XCTAssertTrue(app.staticTexts["pagination-loading-label"].waitForExistence(timeout: 3))
        app.buttons["switch-profile"].tap()
        XCTAssertTrue(app.buttons["profile-kids-a"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["pagination-loading-label"].exists)
        choose("kids-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(table.cells.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(table.cells.count, 24)
        XCTAssertFalse(app.staticTexts["pagination-loading-label"].exists)
        for cell in table.cells.allElementsBoundByIndex {
            for rating in ["12+", "15+", "19+"] {
                XCTAssertFalse(cell.label.contains(rating))
            }
        }
    }

    func testDetailRetryDisablesUntilResponseCompletes() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-slow-catalog"]
        app.launch()
        choose("adult-a", in: app)
        app.collectionViews["home-catalog"].cells.firstMatch.tap()
        let retry = app.buttons["detail-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: retry)
        waitForExpectations(timeout: 2)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: retry)
        waitForExpectations(timeout: 8)
        let title = app.staticTexts["detail-title"]
        let loadedTitle = title.label
        retry.tap()
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: retry)
        waitForExpectations(timeout: 2)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: retry)
        waitForExpectations(timeout: 8)
        XCTAssertEqual(title.label, loadedTitle)
        XCTAssertTrue(app.buttons["phase2-playback"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.collectionViews["home-catalog"].waitForExistence(timeout: 5))
    }

    func testRapidDetailEntryExit() {
        let app = launch()
        choose("adult-a", in: app)
        for _ in 0..<20 {
            let first = app.collectionViews["home-catalog"].cells.firstMatch
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            first.tap()
            XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 2))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(app.collectionViews["home-catalog"].cells.firstMatch.waitForExistence(timeout: 5))
    }
    func testLargeTextAccessibilityAudit() throws {
        let app = launch(largeText: true)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
        choose("kids-a", in: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
        app.collectionViews["home-catalog"].cells.firstMatch.tap()
        XCTAssertTrue(app.buttons["phase2-playback"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
    }
}
