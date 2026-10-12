import XCTest

@MainActor final class StreamLabUITests: XCTestCase {
    private func launch(largeText: Bool = false, slow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if slow { app.launchArguments.append("--ui-test-slow-catalog") }
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 12), file: file, line: line)
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
        element.tap()
    }

    private func choose(_ id: String, in app: XCUIApplication) {
        tap(app.buttons["profile-\(id)"], in: app)
        XCTAssertTrue(app.buttons["hero-detail"].waitForExistence(timeout: 12))
    }

    private func expectCount(_ count: Int, in app: XCUIApplication) {
        // Lazy containers expose only realized rows. Assert the model-backed visible count,
        // not UIKit cell count or a requirement to materialize all 2,000 rows.
        let counter = app.staticTexts["search-result-count"]
        expectation(for: NSPredicate(format: "label == %@", "결과 \(count)개"), evaluatedWith: counter)
        waitForExpectations(timeout: 12)
    }

    private func searchRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-title-"))
    }

    private func openHomeDetail(_ app: XCUIApplication) {
        tap(app.buttons["hero-detail"], in: app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func assertVisibleKidsRows(_ app: XCUIApplication) {
        XCTAssertGreaterThan(searchRows(app).count, 0)
        for row in searchRows(app).allElementsBoundByIndex {
            for forbidden in ["12+", "15+", "19+"] {
                XCTAssertFalse(row.label.contains(forbidden))
            }
        }
    }

    func testColdLaunchAndRelaunchShowProfiles() {
        let app = XCUIApplication()
        for _ in 0..<2 {
            app.launch()
            for id in ["adult-a", "adult-b", "kids-a"] {
                let button = app.buttons["profile-\(id)"]
                XCTAssertTrue(button.waitForExistence(timeout: 10))
                XCTAssertTrue(button.isHittable)
            }
            app.terminate()
        }
    }

    func testSwiftUIScreensAndPhase2Notice() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["phase2-playback"], in: app)
        XCTAssertTrue(app.alerts["Phase 2 예정"].waitForExistence(timeout: 3))
        app.alerts.buttons["확인"].tap()
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
    }

    func testSearchPaginationAndProfileSwitch() {
        let app = launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        tap(app.buttons["load-more"], in: app)
        expectCount(48, in: app)
        let field = app.textFields["catalog-search-field"]
        field.tap()
        field.typeText("액션")
        tap(app.buttons["switch-profile"], in: app)
        choose("kids-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        XCTAssertEqual(app.textFields["catalog-search-field"].value as? String, "제목 또는 장르 검색")
        assertVisibleKidsRows(app)
    }

    func testSearchPagesSurviveDetailAndTabNavigation() {
        let app = launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        tap(app.buttons["load-more"], in: app)
        expectCount(48, in: app)
        let first = searchRows(app).firstMatch
        let firstID = first.identifier
        tap(first, in: app)
        XCTAssertTrue(app.buttons["phase2-playback"].waitForExistence(timeout: 12))
        back(app)
        expectCount(48, in: app)
        XCTAssertTrue(app.buttons[firstID].exists)
        app.tabBars.buttons["홈"].tap()
        app.tabBars.buttons["검색"].tap()
        expectCount(48, in: app)
    }

    func testPaginationOverlayAppearsAndClears() {
        let app = launch(slow: true)
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        let more = app.buttons["load-more"]
        tap(more, in: app)
        let loading = app.staticTexts["pagination-loading-label"]
        XCTAssertTrue(loading.waitForExistence(timeout: 3))
        XCTAssertFalse(more.isEnabled)
        expectCount(48, in: app)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: loading)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(more.isEnabled)
    }

    func testProfileSwitchDuringPaginationRemovesOverlayAndOldResults() {
        let app = launch(slow: true)
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        tap(app.buttons["load-more"], in: app)
        XCTAssertTrue(app.staticTexts["pagination-loading-label"].waitForExistence(timeout: 3))
        tap(app.buttons["switch-profile"], in: app)
        XCTAssertTrue(app.buttons["profile-kids-a"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["pagination-loading-label"].exists)
        choose("kids-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["pagination-loading-label"])
        waitForExpectations(timeout: 5)
        assertVisibleKidsRows(app)
    }

    func testDetailRetryDisablesUntilResponseCompletes() {
        let app = launch(slow: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["phase2-playback"].waitForExistence(timeout: 12))
        let retry = app.buttons["detail-retry"]
        let title = app.staticTexts["detail-title"]
        let loadedTitle = title.label
        tap(retry, in: app)
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: retry)
        waitForExpectations(timeout: 3)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: retry)
        waitForExpectations(timeout: 12)
        XCTAssertEqual(title.label, loadedTitle)
        back(app)
        XCTAssertTrue(app.buttons["hero-detail"].waitForExistence(timeout: 5))
    }

    func testRapidDetailEntryExit() { exerciseDetailNavigation(cycles: 20) }

    func testReleaseNavigationSoak() {
        // Also selected by the Release runtime script. This is not a leak measurement.
        exerciseDetailNavigation(cycles: 60)
    }

    private func exerciseDetailNavigation(cycles: Int) {
        let app = launch()
        choose("adult-a", in: app)
        for cycle in 0..<cycles {
            openHomeDetail(app)
            back(app)
            XCTAssertTrue(app.buttons["hero-detail"].waitForExistence(timeout: 5))
            if (cycle + 1).isMultiple(of: 20) {
                let checkpoint = XCTAttachment(screenshot: app.screenshot())
                checkpoint.name = "Home after \(cycle + 1) detail cycles"
                checkpoint.lifetime = .keepAlways
                add(checkpoint)
            }
        }
    }

    func testBackgroundDuringPaginationResumesWithoutLosingPages() {
        let app = launch(slow: true)
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        tap(app.buttons["load-more"], in: app)
        XCTAssertTrue(app.staticTexts["pagination-loading-label"].waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        app.activate()
        expectCount(48, in: app)
        XCTAssertTrue(app.buttons["load-more"].isEnabled)
    }

    func testLargeTextAccessibilityAudit() throws {
        let app = launch(largeText: true)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
        choose("kids-a", in: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["phase2-playback"].waitForExistence(timeout: 12))
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
        back(app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
    }
}
