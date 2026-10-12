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
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 12))
    }

    private func expectCount(_ count: Int, in app: XCUIApplication) {
        // Lazy containers expose only realized rows. Assert the model-backed visible count,
        // not UIKit cell count or a requirement to materialize all 2,000 rows.
        let counter = app.staticTexts["search-result-count"]
        expectation(for: NSPredicate(format: "label == %@", "결과 \(count)개"), evaluatedWith: counter)
        waitForExpectations(timeout: 12)
    }

    private func searchRows(_ app: XCUIApplication) -> XCUIElementQuery {
        // SwiftUI NavigationLink may be exposed as a Link or another AX element.
        // Resolve its stable identifier without assuming UIKit's Button type.
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-title-"))
    }

    private func openHomeDetail(_ app: XCUIApplication) {
        tap(app.descendants(matching: .any)["hero-detail"], in: app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func assertVisibleKidsRows(_ app: XCUIApplication) {
        XCTAssertTrue(searchRows(app).firstMatch.waitForExistence(timeout: 12))
        XCTAssertGreaterThan(searchRows(app).count, 0)
        for row in searchRows(app).allElementsBoundByIndex {
            XCTAssertTrue(row.label.contains("ALL") || row.label.contains("7+"), "Missing allowed rating: \(row.label)")
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

    func testSwiftUIScreensAndPlayback() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["playback-open"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-forward"], in: app)
        let time = app.staticTexts["playback-time"]
        expectation(for: NSPredicate(format: "label MATCHES %@", "(1[0-9]|2[0-9]|30)초 / 30초"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        tap(app.buttons["playback-close"], in: app)
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
    }

    private func expectPlayback(_ status: String, in app: XCUIApplication) {
        let label = app.staticTexts["playback-status"]
        expectation(for: NSPredicate(format: "label == %@", status), evaluatedWith: label)
        waitForExpectations(timeout: 15)
    }

    func testPlaybackRetryAfterMissingResource() {
        let app = XCUIApplication()
        app.launchArguments.append("--playback-missing-resource-once")
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["playback-open"], in: app)
        tap(app.buttons["playback-retry"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-close"], in: app)
    }

    func testPlaybackCloseDuringAuthorizationAndReopenForKids() {
        let app = launch(slow: true)
        choose("kids-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["playback-open"], in: app)
        tap(app.buttons["playback-close"], in: app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
        tap(app.buttons["playback-open"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-close"], in: app)
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        XCTAssertFalse(app.buttons["playback-close"].exists)
    }

    func testPlaybackPausesAfterBackground() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["playback-open"], in: app)
        expectPlayback("재생 중", in: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-close"], in: app)
    }

    func testMyListPersistsAndIsolatesProfiles() {
        let app = launch()
        choose("adult-a", in: app)
        let saved = app.buttons["hero-my-list"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        if saved.value as? String == "추가됨" { tap(saved, in: app) }
        tap(saved, in: app)
        XCTAssertEqual(saved.value as? String, "추가됨")
        XCTAssertFalse(app.staticTexts["detail-title"].exists)
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["detail-my-list"].waitForExistence(timeout: 12))
        XCTAssertEqual(app.buttons["detail-my-list"].value as? String, "추가됨")
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        // Establish a known B state, then verify A's saved state is independent.
        if app.buttons["hero-my-list"].value as? String == "추가됨" {
            tap(app.buttons["hero-my-list"], in: app)
        }
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        XCTAssertEqual(saved.value as? String, "추가됨")
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        XCTAssertEqual(saved.value as? String, "추가됨")
        tap(app.buttons["home-category-나의 리스트"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "my-list-", "my-list-empty")).firstMatch.exists)
        tap(app.buttons["home-category-추천"], in: app)
        tap(saved, in: app)
        XCTAssertEqual(saved.value as? String, "추가 안 됨")
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
        XCTAssertEqual(app.textFields["catalog-search-field"].value as? String, "검색어")
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
        XCTAssertTrue(first.waitForExistence(timeout: 12))
        let firstID = first.identifier
        tap(first, in: app)
        XCTAssertTrue(app.buttons["playback-open"].waitForExistence(timeout: 12))
        back(app)
        expectCount(48, in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: firstID).firstMatch.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["playback-open"].waitForExistence(timeout: 12))
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
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 5))
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
            XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 5))
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

    private func auditLargeText(_ app: XCUIApplication) throws {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Large text UI hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Large text audit screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        // Keep all audit failures visible; do not filter or ignore text clipping.
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion])
    }

    func testLargeTextAccessibilityAudit() throws {
        let app = launch(largeText: true)
        try auditLargeText(app)
        choose("kids-a", in: app)
        try auditLargeText(app)
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["playback-open"].waitForExistence(timeout: 12))
        try auditLargeText(app)
        back(app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        try auditLargeText(app)
    }
}
