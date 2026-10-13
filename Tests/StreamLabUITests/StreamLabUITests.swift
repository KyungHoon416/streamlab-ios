import XCTest

@MainActor final class StreamLabUITests: XCTestCase {
    private var playbackReturnFrame: CGRect?

    func testSubtitleSelectionSeekingAndReset() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.1667)
        expectation(for: NSPredicate(format: "label MATCHES %@", "[4-6]초 / 30초"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        let caption = app.staticTexts["playback-caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        tap(app.buttons["playback-forward"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "자막 선택에서 언어를 바꿀 수 있습니다."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-backward"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "StreamLab 데모 영상입니다."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-en"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "Welcome to the StreamLab demo."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-off"], in: app)
        XCTAssertFalse(caption.exists)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "끄기")
        XCTAssertFalse(caption.exists)
        closePlayback(app)
    }

    func testPausedSeekTimeoutRecoversControls() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-stall-seek-once")
        app.launchArguments.append("--ui-test-disable-resume")
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-forward"], in: app)
        XCTAssertTrue(app.staticTexts["playback-seek-message"].waitForExistence(timeout: 12))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.progressIndicators["playback-loading"])
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-toggle"])
        waitForExpectations(timeout: 5)
        expectPlayback("일시 정지", in: app)
        for _ in 0..<3 {
            tap(app.buttons["playback-backward"], in: app)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-forward"])
            waitForExpectations(timeout: 5)
            expectPlayback("일시 정지", in: app)
            tap(app.buttons["playback-forward"], in: app)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-toggle"])
            waitForExpectations(timeout: 5)
            expectPlayback("일시 정지", in: app)
        }
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
    }

    func testPlaybackResumeAfterRelaunchAndRestart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=streamlab-uitest-\(UUID())"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.5)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-toggle"])
        expectation(for: NSPredicate(format: "label MATCHES %@", "1[3-7]초 / 30초"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        closePlayback(app)
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        XCTAssertTrue(app.staticTexts["playback-resumed"].waitForExistence(timeout: 10))
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        expectation(for: NSPredicate(format: "label MATCHES %@", "(1[3-9]|2[0-4])초 / 30초"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-restart"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "0초 / 30초"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCTAssertFalse(app.staticTexts["playback-resumed"].exists)
        closePlayback(app)
    }

    private func launch(largeText: Bool = false, slow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if slow { app.launchArguments.append("--ui-test-slow-catalog") }
        app.launchArguments.append("--ui-test-disable-resume")
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let reveal = app.buttons["playback-reveal-controls"]
        if reveal.exists { reveal.tap() }
        guard element.waitForExistence(timeout: 12) else {
            XCTFail("Target did not appear: \(element)", file: file, line: line)
            return
        }
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        guard element.isHittable else {
            XCTFail("Target is not hittable: \(element)", file: file, line: line)
            return
        }
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

    private func openPlayback(_ app: XCUIApplication) {
        playbackReturnFrame = app.frame
        tap(app.buttons["playback-open"], in: app)
    }

    private func closePlayback(_ app: XCUIApplication) {
        tap(app.buttons["playback-close"], in: app)
        // Cover dismissal and scene rotation are separate transitions. Neither a tap
        // returning nor the underlying detail existing proves both have completed.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["playback-close"])
        if let frame = playbackReturnFrame {
            print("[PlaybackReturn] Waiting for original window frame: \(frame)")
            expectation(for: NSPredicate(format: "frame == %@", NSValue(cgRect: frame)), evaluatedWith: app)
        }
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
        let backButton = app.navigationBars.buttons["BackButton"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: backButton)
        waitForExpectations(timeout: 5)
    }

    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons["BackButton"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: button)
        waitForExpectations(timeout: 5)
        button.tap()
        // Fail at the actual navigation boundary instead of cascading into profile taps.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["detail-title"])
        waitForExpectations(timeout: 5)
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
            app.launchArguments.append("--ui-test-disable-resume")
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
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-forward"], in: app)
        let time = app.staticTexts["playback-time"]
        expectation(for: NSPredicate(format: "label MATCHES %@", "(1[0-9]|2[0-9]|30)초 / 30초"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        closePlayback(app)
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
    }

    private func expectPlayback(_ status: String, in app: XCUIApplication) {
        let reveal = app.buttons["playback-reveal-controls"]
        if reveal.exists { reveal.tap() }
        let label = app.staticTexts["playback-status"]
        expectation(for: NSPredicate(format: "label == %@", status), evaluatedWith: label)
        waitForExpectations(timeout: 15)
    }

    func testCustomPlaybackLandscapeAndControls() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        let reveal = app.buttons["playback-reveal-controls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10), "Playing controls should hide after inactivity.")
        XCTAssertGreaterThan(app.frame.width, app.frame.height, "Player should request landscape on a full-screen iPhone.")
        reveal.tap()
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        let slider = app.sliders["playback-position"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        let time = app.staticTexts["playback-time"]
        expectation(for: NSPredicate(format: "label MATCHES %@", "1[3-7]초 / 30초"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        tap(app.buttons["playback-fit"], in: app)
        XCTAssertEqual(app.buttons["playback-fit"].value as? String, "화면 채우기")
        tap(app.buttons["playback-fit"], in: app)
        XCTAssertEqual(app.buttons["playback-fit"].value as? String, "영상 전체 보기")
        closePlayback(app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["playback-toggle"].exists)
        // Reopening creates a fresh player rather than resuming the closed instance.
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
    }

    func testPlaybackLargeTextControls() throws {
        let app = launch(largeText: true)
        choose("kids-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        try auditLargeText(app, screen: "custom-player-large-text")
        closePlayback(app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
    }

    func testPlaybackRetryAfterMissingResource() {
        let app = XCUIApplication()
        app.launchArguments.append("--playback-missing-resource-once")
        app.launchArguments.append("--ui-test-disable-resume")
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        tap(app.buttons["playback-retry"], in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
    }

    func testPlaybackCloseDuringAuthorizationAndReopenForKids() {
        let app = launch(slow: true)
        choose("kids-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        closePlayback(app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        XCTAssertFalse(app.buttons["playback-close"].exists)
    }

    func testPlaybackPausesAfterBackground() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
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
        app.launchArguments.append("--ui-test-disable-resume")
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

    private func revealDetailElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let scroll = app.scrollViews["detail-scroll"]
        guard scroll.waitForExistence(timeout: 5), element.waitForExistence(timeout: 5) else {
            XCTFail("Missing detail scroll container or checkpoint: \(element.identifier)")
            return false
        }

        for attempt in 0...12 {
            let scrollFrame = scroll.frame
            var viewport = scrollFrame.intersection(app.frame)
            if app.navigationBars.firstMatch.exists {
                let top = max(viewport.minY, app.navigationBars.firstMatch.frame.maxY)
                viewport = CGRect(x: viewport.minX, y: top, width: viewport.width,
                                  height: max(0, viewport.maxY - top))
            }
            if app.tabBars.firstMatch.exists {
                viewport.size.height = max(0, min(viewport.maxY, app.tabBars.firstMatch.frame.minY) - viewport.minY)
            }
            viewport = viewport.insetBy(dx: 8, dy: 8)
            let frame = element.frame
            print("[DetailScroll] \(element.identifier) attempt=\(attempt) frame=\(frame) viewport=\(viewport) hittable=\(element.isHittable)")
            if viewport.contains(frame) && element.isHittable { return true }
            guard attempt < 12, viewport.width > 0, viewport.height > 80 else { break }

            // Keep both ends inside the visible content, away from navigation and tab bars.
            let distance = min(viewport.height * 0.55, max(-viewport.height * 0.55, frame.midY - viewport.midY))
            let startY = viewport.midY + distance / 2
            let endY = viewport.midY - distance / 2
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX - scrollFrame.minX,
                                                   dy: startY - scrollFrame.minY))
            let end = origin.withOffset(CGVector(dx: viewport.midX - scrollFrame.minX,
                                                 dy: endY - scrollFrame.minY))
            start.press(forDuration: 0.1, thenDragTo: end)
        }

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Unreachable detail checkpoint - \(element.identifier)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Unreachable detail checkpoint screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTFail("Detail checkpoint must be fully visible and hittable at maximum text size: \(element.identifier), frame=\(element.frame)")
        return false
    }

    private func auditLargeText(_ app: XCUIApplication, screen: String) throws {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(screen) - Large text UI hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(screen) - Large text audit screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        // Keep all audit failures visible; do not filter or ignore text clipping.
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion]) { issue in
            var details = "[AccessibilityAudit] \(screen): \(issue.compactDescription)\n\(issue.detailedDescription)"
            if let element = issue.element {
                details += "\nidentifier=\(element.identifier)\nlabel=\(element.label)\nframe=\(element.frame)"
                details += "\n\(element.debugDescription)"
            } else {
                details += "\nNo element supplied by XCTest."
            }
            print(details)
            let attachment = XCTAttachment(string: details)
            attachment.name = "\(screen) - Accessibility issue"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false // Record the failure; never accept or suppress an audit issue.
        }
    }

    func testLargeTextAccessibilityAudit() throws {
        let app = launch(largeText: true)
        try auditLargeText(app, screen: "profiles")
        choose("kids-a", in: app)
        try auditLargeText(app, screen: "home")
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["playback-open"].waitForExistence(timeout: 12))
        try auditLargeText(app, screen: "detail-top")
        // Reach each checkpoint before auditing. Do not interleave audits with scroll gestures:
        // audits can change text size/layout, so each checkpoint resolves fresh geometry.
        for identifier in ["playback-open", "detail-my-list", "detail-retry"] {
            let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            guard revealDetailElement(element, in: app) else { return }
            try auditLargeText(app, screen: identifier)
        }
        back(app)
        app.tabBars.buttons["검색"].tap()
        expectCount(24, in: app)
        try auditLargeText(app, screen: "search")
    }
}

