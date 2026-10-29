import XCTest

@MainActor final class StreamLabUITests: XCTestCase {
    private var playbackReturnFrame: CGRect?

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func captureFailure(_ app: XCUIApplication, name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }


    private func selectEpisodeDemo(_ app: XCUIApplication) {
        tap(app.buttons["playback-source"], in: app)
        tap(app.buttons["source-demo-series-episode-1-v1"], in: app)
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("1화"))
    }

    private func launchDownloadLifecycle(slow: Bool = false, transferPressure: Bool = false) throws -> XCUIApplication {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_DOWNLOADS"] == "1",
                          "Requires real external HLS transfers; run the download lifecycle gate.")
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=download-lifecycle-\(UUID())",
                               "--ui-test-download-lifecycle", "--ui-test-disable-resume"]
        if slow { app.launchArguments.append("--ui-test-slow-catalog") }
        if transferPressure { app.launchArguments.append("--ui-test-transfer-pressure") }
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        addTeardownBlock { @MainActor [weak self] in
            guard let self else { return }
            app.activate()
            if app.buttons["account-logout"].exists {
                self.tap(app.buttons["account-logout"], in: app)
                self.tap(app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
                XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
            }
        }
        return app
    }

    func testHLSPauseResumeUsesSameTaskAndCompletes() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let pause = app.buttons["library-title-0001-pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        revealDownloadElement(pause, in: app)
        tap(pause, in: app)
        let resume = app.buttons["library-title-0001-resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        let paused = downloadSnapshot(app)
        XCTAssertTrue(paused.contains("active=0;"), paused)
        XCTAssertTrue(paused.contains("paused=1;suspended=1"), paused)
        XCTAssertTrue(paused.contains("started=1;"), paused)
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(5))
        app.activate()
        let returned = downloadSnapshot(app)
        XCTAssertTrue(returned.contains("paused=1;suspended=1"), returned)
        XCTAssertTrue(returned.contains("notifications=0;"), returned)
        revealDownloadElement(resume, in: app)
        tap(resume, in: app)
        let resumed = downloadSnapshot(app)
        XCTAssertTrue(resumed.contains("started=1;"), resumed)
        XCTAssertTrue(resumed.contains("paused=0;suspended=0"), resumed)
        let play = app.buttons["library-title-0001-play"]
        XCTAssertTrue(play.waitForExistence(timeout: 180))
    }

    func testHLSPausedTransferLogoutRemovesNativeTask() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let pause = app.buttons["library-title-0001-pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        revealDownloadElement(pause, in: app)
        tap(pause, in: app)
        XCTAssertTrue(downloadSnapshot(app).contains("paused=1;suspended=1"))
        tap(app.buttons["account-logout"], in: app)
        tap(app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
        XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let cleared = downloadSnapshot(app)
        XCTAssertTrue(cleared.contains("native=0;active=0;queued=0;complete=0;records=0;disk=0;files=0;"), cleared)
        XCTAssertTrue(cleared.contains("notifications=0;"), cleared)
    }

    func testHLSPausedRelaunchNeverAutoResumesAndCanCancel() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let pause = app.buttons["library-title-0001-pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 15))
        revealDownloadElement(pause, in: app)
        tap(pause, in: app)
        XCTAssertTrue(downloadSnapshot(app).contains("paused=1;suspended=1"))
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let restored = downloadSnapshot(app)
        XCTAssertTrue(restored.contains("active=0;queued=0;complete=0;records=1;disk=1;"), restored)
        // A user force-quit may remove the OS task. Either retain paused work or
        // expose retryable failure; never silently restart or create a duplicate.
        if restored.contains("native=1;") {
            XCTAssertTrue(restored.contains("paused=1;suspended=1"), restored)
        } else {
            XCTAssertTrue(restored.contains("native=0;"), restored)
            XCTAssertTrue(app.buttons["library-title-0001-retry"].exists)
        }
        let cancel = app.buttons["library-title-0001-delete"]
        revealDownloadElement(cancel, in: app)
        tap(cancel, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["downloads-empty"].waitForExistence(timeout: 15))
        let cleared = downloadSnapshot(app)
        XCTAssertTrue(cleared.contains("native=0;active=0;queued=0;complete=0;records=0;disk=0;"), cleared)
        XCTAssertTrue(cleared.contains("notifications=0;"), cleared)
    }

    func testHLSExpirationSurvivesRelaunchAndRedownloads() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let play = app.buttons["library-title-0001-play"]
        app.scrollViews["downloads-scroll"].swipeUp()
        XCTAssertTrue(play.waitForExistence(timeout: 180))
        let expire = app.buttons["download-validation-expire"]
        for _ in 0..<5 {
            if expire.exists && expire.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeDown()
        }
        tap(expire, in: app)
        let expired = app.staticTexts["library-title-0001-expired"]
        revealDownloadElement(expired, in: app)
        XCTAssertTrue(expired.waitForExistence(timeout: 10))
        XCTAssertFalse(play.exists)
        let attempt = app.buttons["download-validation-play-expired"]
        for _ in 0..<5 {
            if attempt.exists && attempt.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeDown()
        }
        tap(attempt, in: app)
        let denied = app.alerts["영상을 불러올 수 없습니다"]
        XCTAssertTrue(denied.waitForExistence(timeout: 15), "Expired content must be rejected by the actual playback gate")
        tap(denied.buttons["취소"], in: app)
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        revealDownloadElement(expired, in: app)
        XCTAssertTrue(expired.exists)
        XCTAssertFalse(play.exists)
        let retry = app.buttons["library-title-0001-retry"]
        revealDownloadElement(retry, in: app)
        tap(retry, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: 180))
        XCTAssertFalse(expired.exists)
        XCTAssertTrue(app.staticTexts["library-title-0001-expiry"].exists)
    }

    func testHLSTransferDiskPressureCleansConcurrentTasksAndRecovers() throws {
        let app = try launchDownloadLifecycle(transferPressure: true)
        tap(app.buttons["download-validation-three"], in: app)
        let firstRetry = app.buttons["library-title-0001-retry"]
        // Rows are lazy and may be below the viewport; wait for native cleanup,
        // then scroll to each user-facing failure message.
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let state = self.downloadSnapshot(app)
            return state.contains("native=0;active=0;queued=0;complete=0;records=3;") && state.contains("cleaning=0")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 120), .completed)
        let blocked = downloadSnapshot(app)
        XCTAssertTrue(blocked.contains("native=0;active=0;queued=0;complete=0;records=3;"), blocked)
        XCTAssertTrue(blocked.contains("files=0;"), blocked)
        XCTAssertTrue(blocked.contains("started=2;"), blocked)
        XCTAssertTrue(blocked.contains("peak=2;"), blocked)
        XCTAssertTrue(blocked.contains("notifications=0;"), blocked)
        XCTAssertTrue(blocked.contains("disk=3;"), blocked)
        for number in [1, 2] {
            let message = app.staticTexts[String(format: "library-title-%04d-failed", number)]
            revealDownloadElement(message, in: app)
            XCTAssertTrue(message.label.contains("기기 저장 공간이 부족해"), message.label)
        }
        _ = downloadSnapshot(app)
        tap(app.buttons["download-validation-low-disk"], in: app)
        revealDownloadElement(firstRetry, in: app)
        tap(firstRetry, in: app)
        XCTAssertTrue(app.buttons["library-title-0001-play"].waitForExistence(timeout: 180))
        let recovered = downloadSnapshot(app)
        XCTAssertTrue(recovered.contains("complete=1;records=3;"), recovered)
        XCTAssertTrue(recovered.contains("started=3;"), recovered)
        XCTAssertTrue(recovered.contains("native=0;active=0;queued=0;"), recovered)
    }

    func testHLSDiskPressureProtectsPinnedAndRetryRecovers() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let firstPlay = app.buttons["library-title-0001-play"]
        app.scrollViews["downloads-scroll"].swipeUp()
        XCTAssertTrue(firstPlay.waitForExistence(timeout: 180))
        let pin = app.buttons["library-title-0001-pin"]
        revealDownloadElement(pin, in: app)
        tap(pin, in: app)
        XCTAssertTrue(pin.label.contains("고정 해제"))
        _ = downloadSnapshot(app)
        let pressure = app.buttons["download-validation-low-disk"]
        tap(pressure, in: app)
        tap(app.buttons["download-validation-three"], in: app)
        let secondRetry = app.buttons["library-title-0002-retry"]
        XCTAssertTrue(secondRetry.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["library-title-0003-retry"].waitForExistence(timeout: 20))
        let blocked = downloadSnapshot(app)
        XCTAssertTrue(blocked.contains("native=0;active=0;queued=0;complete=1;records=3;"), blocked)
        XCTAssertTrue(blocked.contains("files=1;"), blocked)
        XCTAssertTrue(blocked.contains("started=1;"), blocked)
        XCTAssertTrue(firstPlay.exists)
        XCTAssertTrue(pin.label.contains("고정 해제"))
        tap(pressure, in: app)
        revealDownloadElement(secondRetry, in: app)
        tap(secondRetry, in: app)
        XCTAssertTrue(app.buttons["library-title-0002-play"].waitForExistence(timeout: 180))
        let recovered = downloadSnapshot(app)
        XCTAssertTrue(recovered.contains("complete=2;records=3;"), recovered)
        XCTAssertTrue(recovered.contains("started=2;"), recovered)
        XCTAssertTrue(firstPlay.exists)
        XCTAssertTrue(pin.label.contains("고정 해제"))
    }

    func testStartupChromeBaseline() { checkStartupChrome("baseline") }
    func testStartupChromeNoToolbar() { checkStartupChrome("no-toolbar") }
    func testStartupChromeNoTabs() { checkStartupChrome("no-tabs") }
    func testStartupChromeIgnoredWithoutTracing() { checkStartupChrome("no-tabs", tracing: false) }

    func testStartupTabsLegacy() { checkStartupChrome("baseline", builder: "legacy") }
    func testStartupTabsExplicit() { checkStartupChrome("baseline", builder: "explicit") }

    private func checkStartupChrome(_ mode: String, tracing: Bool = true, builder: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=chrome-\(UUID())", "--ui-test-disable-resume",
                               "--home-render-experiment=C", "--startup-chrome=\(mode)"]
        if tracing { app.launchArguments.append("--trace-home-startup") }
        if let builder { app.launchArguments.append("--startup-tab-builder=\(builder)") }
        app.launch()
        choose("adult-a", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 15))
        let effective = tracing ? mode : "baseline"
        XCTAssertEqual(app.tabBars.buttons["검색"].exists, effective != "no-tabs")
        XCTAssertEqual(app.buttons["switch-profile"].exists, effective != "no-toolbar")
        XCTAssertEqual(app.buttons["account-logout"].exists, effective != "no-toolbar")
        openHomeDetail(app)
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 10))
        back(app)
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 10))
        if builder != nil {
            tap(app.tabBars.buttons["검색"], in: app)
            tap(app.tabBars.buttons["다운로드"], in: app)
            tap(app.tabBars.buttons["홈"], in: app)
            XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 10))
        }
    }

    func testStartupTraceControl() { checkPosterNavigation(mode: "C", poster: "swiftui", home: "inline", trace: true) }
    func testStartupTraceCombined() { checkPosterNavigation(mode: "PV", poster: "layer", home: "split", trace: true) }

    func testHomeExperimentControl() { checkPosterNavigation(mode: "C", poster: "swiftui", home: "inline") }
    func testHomeExperimentPoster() { checkPosterNavigation(mode: "P", poster: "layer", home: "inline") }
    func testHomeExperimentSplit() { checkPosterNavigation(mode: "V", poster: "swiftui", home: "split") }
    func testHomeExperimentCombined() { checkPosterNavigation(mode: "PV", poster: "layer", home: "split") }

    func testPosterImageAndSearchThumbnailOpenDetail() { checkPosterNavigation() }

    private func checkPosterNavigation(mode: String? = nil, poster: String = "layer", home: String = "split", trace: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=artwork-tap-\(UUID())", "--ui-test-disable-resume"]
        if let mode { app.launchArguments.append("--home-render-experiment=\(mode)") }
        if trace { app.launchArguments.append("--trace-home-startup") }
        app.launch()
        choose("adult-a", in: app)
        let catalog = app.scrollViews["home-catalog"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 15))
        XCTAssertEqual(catalog.value as? String, "home_render_experiment=\(mode ?? "PV") poster=\(poster) home=\(home)")
        let card = app.descendants(matching: .any)["rail-trending-title-0001"]
        for _ in 0..<6 {
            if card.exists && card.frame.minY > 100 && card.frame.maxY < app.frame.maxY - 100 { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(card.exists && card.isHittable)
        print("Poster frame: \(card.frame)")
        let posterSnapshot = XCTAttachment(screenshot: card.screenshot())
        posterSnapshot.name = "poster-rendered-bounds"
        posterSnapshot.lifetime = .keepAlways
        add(posterSnapshot)
        // Tap inside the artwork, away from the title and top-left badge.
        card.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 80, dy: 100)).tap()
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 10))
        tap(app.tabBars.buttons["검색"], in: app)
        let row = searchRows(app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 50)).tap()
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 10))
    }

    func testPreviewContinuesWithoutInteractionAfterRotation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=preview-unattended-\(UUID())", "--ui-test-disable-resume"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["detail-preview"], in: app)
        expectPlayback("재생 중", in: app)
        // Observe without touching controls while the initial landscape transition settles.
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            let paused = app.descendants(matching: .any).matching(NSPredicate(
                format: "(identifier == %@ AND label == %@) OR (identifier == %@ AND value == %@)",
                "playback-status", "일시 정지", "playback-reveal-controls", "일시 정지")).firstMatch
            XCTAssertFalse(paused.exists, "Preview paused without user interaction")
        }
        expectPlayback("재생 중", in: app)
        closePlayback(app)
    }

    func testIncreasedContrastAndReducedMotionPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=accessibility-display-\(UUID())",
                               "--ui-test-disable-resume", "--ui-test-keep-playback-controls",
                               "--ui-test-increased-contrast", "--ui-test-reduce-motion"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        choose("adult-a", in: app)
        tap(app.buttons["hero-playback"], in: app)
        expectPlayback("재생 중", in: app)
        XCTAssertGreaterThan(app.frame.height, app.frame.width, "Reduced motion must not automatically rotate the player")
        for identifier in ["playback-toggle", "playback-backward", "playback-forward", "playback-close"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.isHittable, identifier)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, identifier)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, identifier)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Increased contrast player, reduced motion"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        try app.performAccessibilityAudit(for: [.contrast])
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-forward"], in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-rotate"], in: app)
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        expectation(for: rotated, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        tap(app.buttons["playback-close"], in: app)
        XCTAssertTrue(app.buttons["hero-playback"].waitForExistence(timeout: 10))
    }

    func testHomeDemoContinuesWithoutInteraction() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=home-demo-unattended-\(UUID())", "--ui-test-disable-resume"]
        app.launch()
        choose("adult-a", in: app)
        tap(app.buttons["hero-playback"], in: app)
        expectPlayback("재생 중", in: app)
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            let paused = app.descendants(matching: .any).matching(NSPredicate(
                format: "(identifier == %@ AND label == %@) OR (identifier == %@ AND value == %@)",
                "playback-status", "일시 정지", "playback-reveal-controls", "일시 정지")).firstMatch
            XCTAssertFalse(paused.exists, "Home demo paused without user interaction")
        }
        expectPlayback("재생 중", in: app)
        let reveal = app.buttons["playback-reveal-controls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(reveal.frame.width, 44)
        XCTAssertGreaterThanOrEqual(reveal.frame.height, 44)
        XCTAssertTrue(reveal.isHittable)
        reveal.tap()
        XCTAssertTrue(app.buttons["playback-close"].waitForExistence(timeout: 3))
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-close"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 10))
    }

    func testVisiblePlayButtonRecoversPausedEngineWithPlayingIntent() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=preview-resume-\(UUID())", "--ui-test-disable-resume",
                               "--ui-test-keep-playback-controls", "--ui-test-unrequested-pause-once"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        tap(app.buttons["detail-preview"], in: app)
        expectPlayback("일시 정지", in: app)
        let control = app.buttons["playback-toggle"]
        XCTAssertEqual(control.label, "재생")
        tap(control, in: app)
        expectPlayback("재생 중", in: app)
        XCTAssertEqual(control.label, "일시 정지")
        tap(control, in: app)
        expectPlayback("일시 정지", in: app)
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertEqual(control.label, "재생")
        tap(control, in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
    }

    private func downloadSnapshot(_ app: XCUIApplication) -> String {
        let status = app.staticTexts["download-validation-status"]
        let old = status.label
        let refresh = app.buttons["download-validation-refresh"]
        for _ in 0..<5 {
            if refresh.exists && refresh.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeDown()
        }
        tap(refresh, in: app)
        // Give the asynchronous native-task query time to publish, even if unchanged.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let value = status.label
        print("[DownloadLifecycle] \(value) (previous \(old))")
        return value
    }

    private func revealDownloadElement(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.scrollViews["downloads-scroll"].swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func interruptDownload(_ app: XCUIApplication) {
        tap(app.buttons["download-validation-one"], in: app)
        // Slow catalog mode may take four seconds before enqueue.
        let running = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.downloadSnapshot(app).contains("active=1;")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [running], timeout: 15), .completed)
        tap(app.buttons["download-validation-interrupt"], in: app)
        let retry = app.buttons["library-title-0001-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
    }

    func testFailedHLSRetrySurvivesRelaunchAndCompletes() throws {
        let app = try launchDownloadLifecycle()
        interruptDownload(app)
        let failed = downloadSnapshot(app)
        XCTAssertTrue(failed.contains("native=0;active=0;"), failed)
        XCTAssertTrue(failed.contains("records=1;disk=1;files=0;"), failed)
        let oldAttempt = failed.components(separatedBy: "attempt=").last
        app.terminate(); app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertTrue(app.buttons["library-title-0001-retry"].waitForExistence(timeout: 10))
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertFalse(app.buttons["library-title-0001-retry"].exists)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let retry = app.buttons["library-title-0001-retry"]
        revealDownloadElement(retry, in: app)
        retry.doubleTap()
        app.scrollViews["downloads-scroll"].swipeDown()
        let restarted = downloadSnapshot(app)
        XCTAssertTrue(restarted.contains("native=1;active=1;"), restarted)
        XCTAssertTrue(restarted.contains("records=1;disk=1;"), restarted)
        XCTAssertNotEqual(oldAttempt, restarted.components(separatedBy: "attempt=").last)
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.downloadSnapshot(app).contains("complete=1;")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 180), .completed)
        XCTAssertTrue(downloadSnapshot(app).contains("notifications=0;"), "Foreground retry must not alert")
        let play = app.buttons["library-title-0001-play"]
        revealDownloadElement(play, in: app)
        playbackReturnFrame = app.frame
        tap(play, in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app, returningToDownloads: true)
    }

    func testProfileSwitchDuringRetryDoesNotStartTransfer() throws {
        let app = try launchDownloadLifecycle(slow: true)
        interruptDownload(app)
        let retry = app.buttons["library-title-0001-retry"]
        revealDownloadElement(retry, in: app)
        retry.tap()
        // Invalidate the old session while repository authorization is suspended.
        app.buttons["switch-profile"].tap()
        choose("adult-b", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let other = downloadSnapshot(app)
        // Diagnostics count the account's records; A's failed record must remain.
        XCTAssertTrue(other.contains("native=0;active=0;queued=0;complete=0;records=1;disk=1;"), other)
        XCTAssertTrue(other.contains("peak=1;started=1;"), other)
        XCTAssertTrue(app.staticTexts["downloads-summary"].label.hasPrefix("0개"))
        XCTAssertFalse(app.buttons["library-title-0001-retry"].exists)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertTrue(app.buttons["library-title-0001-retry"].waitForExistence(timeout: 10))
        XCTAssertTrue(downloadSnapshot(app).contains("native=0;active=0;"))
    }

    func testHLSBackgroundDownloadReturnsWithPlayablePackage() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-one"], in: app)
        let started = downloadSnapshot(app)
        XCTAssertTrue(started.contains("active=1;"), started)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        // Real background time, not a simulated completion or a readiness delay.
        RunLoop.current.run(until: Date().addingTimeInterval(45))
        app.activate()
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.downloadSnapshot(app).contains("complete=1;")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 150), .completed)
        let final = downloadSnapshot(app)
        XCTAssertTrue(final.contains("native=0;"), final)
        XCTAssertTrue(final.contains("disk=1;files=1;"), final)
        // The normal library integration separately verifies playback. Here require
        // the store's real AVAssetCache offline-playability completion gate.
        tap(app.buttons["account-logout"], in: app)
        tap(app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
        XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
    }

    func testHLSTwoTransfersQueueThirdAndLogoutCleansNativeTasks() throws {
        let app = try launchDownloadLifecycle()
        tap(app.buttons["download-validation-three"], in: app)
        let started = downloadSnapshot(app)
        XCTAssertTrue(started.contains("native=2;active=2;queued=1;"), started)
        XCTAssertTrue(started.contains("peak=2;started=2"), started)
        XCTAssertTrue(started.contains("disk=3;files=2;"), "Both native packages must exist before logout: \(started)")
        tap(app.buttons["account-logout"], in: app)
        let dialog = app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch
        tap(dialog, in: app)
        XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["logout-error"].exists)
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let cleared = downloadSnapshot(app)
        XCTAssertTrue(cleared.contains("native=0;active=0;queued=0;complete=0;records=0;disk=0;files=0;"), cleared)
        XCTAssertTrue(cleared.contains("notifications=0"), cleared)
        XCTAssertTrue(cleared.contains("peak=2;started=2"), "Queued task must not start during logout: \(cleared)")
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let restored = downloadSnapshot(app)
        XCTAssertTrue(restored.contains("native=0;active=0;queued=0;complete=0;records=0;disk=0;"), restored)
    }

    func testNetworkReconnectBannerAppearsThenDismisses() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=network-banner-\(UUID())", "--ui-test-network-recovery"]
        app.launch()
        let banner = app.descendants(matching: .any)["network-reconnected-banner"]
        XCTAssertFalse(banner.exists, "Initial online must not show recovery")
        XCTAssertTrue(banner.waitForExistence(timeout: 25))
        XCTAssertTrue(banner.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Network restored banner"; shot.lifetime = .keepAlways; add(shot)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: banner)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
    }

    func testDownloadScreenShowsOfflineThenRestoredBanner() {
        let app = launchNetworkScreen()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        verifyOfflineThenRestoredBanner(app)
    }

    func testPlaybackShowsOfflineThenRestoredBanner() {
        let app = launchNetworkScreen()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        verifyOfflineThenRestoredBanner(app)
        XCTAssertFalse(app.alerts["영상을 불러올 수 없습니다"].exists,
                       "Path changes alone must not fail local playback")
    }

    private func launchNetworkScreen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=network-screen-\(UUID())",
                               "--ui-test-network-recovery", "--ui-test-network-screen",
                               "--ui-test-disable-resume", "--ui-test-keep-playback-controls"]
        app.launch()
        return app
    }

    private func verifyOfflineThenRestoredBanner(_ app: XCUIApplication) {
        let offline = app.descendants(matching: .any)["profile-network-banner"].firstMatch
        let restored = app.descendants(matching: .any)["network-reconnected-banner"].firstMatch
        XCTAssertFalse(restored.exists)
        XCTAssertTrue(offline.waitForExistence(timeout: 35))
        XCTAssertTrue(offline.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Offline banner"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(restored.waitForExistence(timeout: 12))
        XCTAssertTrue(restored.isHittable)
        XCTAssertFalse(offline.exists)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: restored)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
    }

    private func enableDownloadNotifications(_ app: XCUIApplication) {
        let enable = app.buttons["download-notification-enable"]
        if enable.exists {
            tap(enable, in: app)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == '허용'")).firstMatch
            XCTAssertTrue(allow.waitForExistence(timeout: 10))
            allow.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["download-notification-enabled"].waitForExistence(timeout: 10),
                      "Notification permission must be granted; denial cannot count as notification success")
    }

    func testHLSCancelledDownloadDoesNotNotify() throws {
        let app = try launchDownloadLifecycle()
        enableDownloadNotifications(app)
        tap(app.buttons["download-validation-one"], in: app)
        XCTAssertTrue(downloadSnapshot(app).contains("active=1;"))
        let cancel = app.buttons["library-title-0001-delete"]
        for _ in 0..<4 {
            if cancel.exists && cancel.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeUp()
        }
        XCTAssertTrue(app.staticTexts["library-title-0001-percentage"].exists, "Cancel must happen during transfer")
        tap(cancel, in: app)
        app.scrollViews["downloads-scroll"].swipeDown()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(8))
        app.activate()
        let cleared = downloadSnapshot(app)
        XCTAssertTrue(cleared.contains("native=0;active=0;queued=0;complete=0;records=0;disk=0;files=0;"), cleared)
        XCTAssertTrue(cleared.contains("notifications=0"), cleared)
    }

    func testHLSBackgroundCompletionNotificationRemovedOnLogout() throws {
        let app = try launchDownloadLifecycle()
        enableDownloadNotifications(app)
        tap(app.buttons["download-validation-one"], in: app)
        let started = downloadSnapshot(app)
        XCTAssertTrue(started.contains("active=1;"), started)
        let percent = app.staticTexts["library-title-0001-percentage"]
        // Scroll to the real progress row before leaving the app.
        for _ in 0..<3 {
            if percent.exists && percent.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeUp()
        }
        if !percent.exists { captureFailure(app, name: "Download percentage missing") }
        XCTAssertTrue(percent.exists)
        XCTAssertTrue(percent.label.contains("%"))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Native download progress"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(55))
        app.activate()
        app.scrollViews["downloads-scroll"].swipeDown()
        let completed = downloadSnapshot(app)
        XCTAssertTrue(completed.contains("complete=1;"), completed)
        XCTAssertTrue(completed.contains("notifications=1"), "Require real OS notification, not just a completed record: \(completed)")
        tap(app.buttons["account-logout"], in: app)
        tap(app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
        XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let cleared = downloadSnapshot(app)
        XCTAssertTrue(cleared.contains("notifications=0"), cleared)
        XCTAssertTrue(cleared.contains("disk=0;files=0;"), cleared)
    }

    func testRealHLSDownloadRelaunchPlaybackAndDelete() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_DOWNLOADS"] == "1",
                          "Downloads use an external Apple HLS sample; run the dedicated opt-in gate.")
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        let start = app.buttons["download-start"]
        guard revealDetailElement(start, in: app) else { return }
        start.tap()
        let completed = app.staticTexts["download-complete"]
        let failed = app.staticTexts["download-failed"]
        let terminal = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in completed.exists || failed.exists }, object: nil)
        let reachedTerminal = XCTWaiter.wait(for: [terminal], timeout: 180) == .completed
        guard reachedTerminal, completed.exists else {
            captureFailure(app, name: "HLS download did not complete")
            XCTFail("Native HLS download must complete; an error or queued state is not success")
            return
        }
        let pin = app.buttons["download-pin"]
        guard revealDetailElement(pin, in: app) else { return }
        pin.tap()
        XCTAssertEqual(pin.value as? String, "고정됨")
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let play = app.buttons["library-title-0001-play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["downloads-summary"].label.hasPrefix("1개"))
        XCTAssertEqual(app.buttons["library-title-0001-pin"].value as? String, "고정됨")
        let libraryScreenshot = XCTAttachment(screenshot: app.screenshot())
        libraryScreenshot.name = "Downloaded sample in profile library"
        libraryScreenshot.lifetime = .keepAlways
        add(libraryScreenshot)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["downloads-empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(play.exists)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        playbackReturnFrame = app.frame
        tap(play, in: app)
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("다운로드한 HLS"))
        closePlayback(app, returningToDownloads: true)
        let libraryPin = app.buttons["library-title-0001-pin"]
        tap(libraryPin, in: app)
        XCTAssertEqual(libraryPin.value as? String, "고정 안 됨")
        tap(app.buttons["library-title-0001-delete"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["downloads-empty"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["downloads-summary"].label.hasPrefix("0개"))
        XCTAssertFalse(play.exists)
        tap(app.tabBars.buttons["홈"], in: app)
        openHomeDetail(app)
        XCTAssertTrue(revealDetailElement(start, in: app))
    }

    func testSystemNotificationTapFromBackgroundDetailDoesNotCrash() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=system-notification-\(UUID())",
                               "--ui-test-system-notification"]
        app.launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        enableDownloadNotifications(app)
        tap(app.tabBars.buttons["홈"], in: app)
        tap(app.buttons["download-system-notification-test"], in: app)
        openHomeDetail(app)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notification = springboard.staticTexts["StreamLab 알림 이동 검증"].firstMatch
        XCTAssertTrue(notification.waitForExistence(timeout: 30), "Requires a real OS notification banner")
        notification.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["다운로드"].isSelected)
        XCTAssertFalse(app.buttons["playback-open"].exists)
    }

    func testDownloadNotificationReturnsFromBackgroundDetailToLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=notification-background-detail-\(UUID())",
                               "--ui-test-download-notification-background"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        XCTAssertTrue(app.buttons["playback-open"].exists)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["다운로드"].isSelected)
        XCTAssertFalse(app.buttons["playback-open"].exists)
        tap(app.tabBars.buttons["홈"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["hero-detail"].waitForExistence(timeout: 10))
    }

    func testDownloadNotificationTapOpensCurrentProfileLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=notification-route-\(UUID())",
                               "--ui-test-download-notification-tap"]
        app.launch()
        choose("adult-b", in: app)
        tap(app.buttons["download-notification-test-tap"], in: app)
        XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["다운로드"].isSelected)
        XCTAssertTrue(app.staticTexts["downloads-profile"].label.contains("Jamie"))
        tap(app.tabBars.buttons["홈"], in: app)
        tap(app.buttons["download-notification-test-tap"], in: app)
        XCTAssertTrue(app.tabBars.buttons["다운로드"].isSelected)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        XCTAssertTrue(app.tabBars.buttons["홈"].isSelected, "Consumed route must not leak into another profile")
    }

    func testDownloadNotificationLaunchWaitsForProfileSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=notification-cold-route-\(UUID())",
                               "--ui-test-download-notification-launch"]
        app.launch()
        enterDemoIfNeeded(app)
        XCTAssertTrue(app.buttons["profile-adult-a"].exists)
        XCTAssertFalse(app.staticTexts["downloads-profile"].exists)
        tap(app.buttons["profile-adult-a"], in: app)
        XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["다운로드"].isSelected)
        tap(app.buttons["account-logout"], in: app)
        tap(app.sheets.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
        XCTAssertTrue(app.buttons["demo-sign-in"].waitForExistence(timeout: 20))
        choose("adult-a", in: app)
        XCTAssertTrue(app.tabBars.buttons["홈"].isSelected, "Old notification must not navigate after logout/sign-in")
    }

    func testDownloadsStorageBudgetSummary() {
        let app = launch()
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        let remaining = app.staticTexts["downloads-storage-remaining"]
        revealDownloadElement(remaining, in: app)
        XCTAssertTrue(remaining.isHittable)
        XCTAssertTrue(remaining.label.contains("남은 예산 1 GB"), remaining.label)
        XCTAssertFalse(app.staticTexts["downloads-storage-guidance"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Download storage budget"; shot.lifetime = .keepAlways; add(shot)
    }

    func testDownloadsLibraryEmptyAtMaximumTextSize() {
        let app = launch(largeText: true)
        choose("adult-a", in: app)
        tap(app.tabBars.buttons["다운로드"], in: app)
        XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["downloads-profile"].isHittable)
        XCTAssertTrue(app.staticTexts["downloads-summary"].label.hasPrefix("0개"))
        XCTAssertFalse(app.buttons["library-title-0001-play"].exists)
        let budget = app.staticTexts["downloads-storage-remaining"]
        revealDownloadElement(budget, in: app)
        XCTAssertTrue(budget.isHittable)
        XCTAssertTrue(budget.label.contains("남은 예산"))
        let empty = app.descendants(matching: .any)["downloads-empty"]
        for _ in 0..<5 {
            if empty.exists && empty.isHittable { break }
            app.scrollViews["downloads-scroll"].swipeUp()
        }
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        if !empty.isHittable { captureFailure(app, name: "Large text download library") }
        XCTAssertTrue(empty.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Download library at maximum text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func finishEpisode(_ app: XCUIApplication) {
        let reveal = app.buttons["playback-reveal-controls"]
        if reveal.exists && reveal.isHittable { reveal.tap() }
        let slider = app.sliders["playback-position"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 1)
        expectPlayback("재생 완료", in: app)
    }

    func testDetailEpisodeSelectionAndProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=streamlab-detail-episodes-\(UUID())"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        let second = app.buttons["detail-episode-2"]
        guard revealDetailElement(second, in: app) else { return }
        XCTAssertEqual(second.value as? String, "이어보기 기록 없음")
        playbackReturnFrame = app.frame
        second.tap()
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("2화"), "Expected episode 2, actual: \(app.staticTexts["playback-source-label"].label)")
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.1667)
        guard waitForPausedSeek(app, timePattern: "00:00:0[4-6] / 00:00:30") else { return }
        closePlayback(app)
        guard revealDetailElement(second, in: app) else { return }
        XCTAssertTrue((second.value as? String ?? "").contains("초부터 이어보기"))
        XCTAssertEqual(app.buttons["detail-episode-1"].value as? String, "이어보기 기록 없음")
        XCTAssertEqual(app.buttons["detail-episode-3"].value as? String, "이어보기 기록 없음")
        playbackReturnFrame = app.frame
        second.tap()
        XCTAssertTrue(app.staticTexts["playback-resumed"].waitForExistence(timeout: 10))
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("2화"), "Expected episode 2, actual: \(app.staticTexts["playback-source-label"].label)")
        closePlayback(app)
    }

    private func openHLSEpisode(_ number: Int, in app: XCUIApplication) {
        openPlaybackSource("hls-series-episode-\(number)-v1", in: app)
    }

    private func openPlaybackSource(_ sourceID: String, in app: XCUIApplication) {
        tap(app.buttons["playback-source"], in: app)
        let list = app.descendants(matching: .any).matching(identifier: "playback-source-list").firstMatch
        guard list.waitForExistence(timeout: 10) else {
            captureFailure(app, name: "Source sheet did not appear")
            XCTFail("Source list must appear before selecting an HLS episode")
            return
        }
        let episode = app.buttons["source-\(sourceID)"]
        // SwiftUI List virtualizes offscreen rows, especially in landscape.
        // Search inside the sheet instead of waiting for a row that has not been materialized.
        for _ in 0..<8 {
            if episode.exists && episode.isHittable { break }
            list.swipeUp()
        }
        // The sheet may preserve an offset from the previously selected source.
        if !(episode.exists && episode.isHittable) {
            for _ in 0..<8 {
                list.swipeDown()
                if episode.exists && episode.isHittable { break }
            }
        }
        guard episode.exists && episode.isHittable else {
            captureFailure(app, name: "HLS source unreachable after list scroll")
            XCTFail("HLS source \(sourceID) must be reachable in the source list")
            return
        }
        episode.tap()
        let playing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "재생 중"),
            object: app.staticTexts["playback-status"])
        guard XCTWaiter.wait(for: [playing], timeout: 45) == .completed else {
            captureFailure(app, name: "HLS episode did not start")
            XCTFail("Real HLS episode failed to start; inspect network and alert")
            return
        }
    }

    private func playbackTimes(_ app: XCUIApplication) -> (position: Double, duration: Double)? {
        let parts = app.staticTexts["playback-time"].label.split(separator: "/")
        guard parts.count == 2 else { return nil }
        func seconds(_ text: Substring) -> Double? {
            let fields = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
            guard (2...3).contains(fields.count) else { return nil }
            let values = fields.compactMap { Double($0) }
            guard values.count == fields.count else { return nil }
            return values.reduce(0) { $0 * 60 + $1 }
        }
        guard let position = seconds(parts[0]), let duration = seconds(parts[1]), duration > 0 else { return nil }
        return (position, duration)
    }

    private func playLastSecondsOfHLSEpisode(_ app: XCUIApplication) {
        // Seek while paused so the position can be verified before the end/countdown.
        // A normalized slider target alone does not prove where AVPlayer actually landed.
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        guard let before = playbackTimes(app), before.duration > 20 else {
            captureFailure(app, name: "HLS duration unavailable")
            XCTFail("Expected a finite HLS duration greater than 20 seconds")
            return
        }
        let slider = app.sliders["playback-position"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        slider.adjust(toNormalizedSliderPosition: CGFloat((before.duration - 10) / before.duration))
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "재생 위치 확인됨"),
            object: app.staticTexts["playback-time"])
        guard XCTWaiter.wait(for: [settled], timeout: 15) == .completed,
              let after = playbackTimes(app),
              after.duration - after.position > 0,
              after.duration - after.position <= 25 else {
            captureFailure(app, name: "HLS end seek did not land near end")
            XCTFail("Expected 1–25 seconds remaining after seek; actual: \(app.staticTexts["playback-time"].label)")
            return
        }
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        // The slider is in the footer. Bring the header back into the visible
        // accessibility viewport before observing the next episode's source label.
        let source = app.staticTexts["playback-source-label"]
        let controls = app.scrollViews["playback-controls-scroll"]
        for _ in 0..<4 {
            if source.exists && source.isHittable { break }
            controls.swipeDown()
        }
        guard source.exists && source.isHittable else {
            captureFailure(app, name: "HLS source header offscreen")
            XCTFail("Episode header must be visible before waiting for automatic advance")
            return
        }
        // Let the real HLS item reach its end naturally; do not inject an ended state.
    }

    func testRealHLSEpisodesAutoAdvanceAndFinalStop() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_REAL_HLS"] == "1",
                          "External HLS integration is opt-in; run check-hls-episodes-mac.sh")
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        openHLSEpisode(1, in: app)
        playLastSecondsOfHLSEpisode(app)
        // Assert the automatic transition itself, not the transient ended label
        // that disappears when the five-second countdown completes.
        let second = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "HLS 테스트 시즌 · 2화"),
            object: app.staticTexts["playback-source-label"])
        guard XCTWaiter.wait(for: [second], timeout: 45) == .completed else {
            captureFailure(app, name: "HLS automatic episode transition failed")
            let status = app.staticTexts["playback-status"]
            let time = app.staticTexts["playback-time"]
            let source = app.staticTexts["playback-source-label"]
            XCTFail("Episode 1 must automatically advance to episode 2. status=\(status.exists ? status.label : "offscreen"), time=\(time.exists ? time.label : "offscreen"), source=\(source.exists ? source.label : "offscreen")")
            return
        }
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "재생 중"),
                                                object: app.staticTexts["playback-status"])
        guard XCTWaiter.wait(for: [playing], timeout: 45) == .completed else {
            captureFailure(app, name: "HLS second episode did not play")
            XCTFail("Automatically selected episode 2 must actually play")
            return
        }
        playLastSecondsOfHLSEpisode(app)
        let ended = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "재생 완료"),
                                              object: app.staticTexts["playback-status"])
        guard XCTWaiter.wait(for: [ended], timeout: 45) == .completed else {
            captureFailure(app, name: "HLS final episode did not end")
            XCTFail("The final HLS episode must reach the ended state")
            return
        }
        let staysEnded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "재생 완료"),
            object: app.staticTexts["playback-status"])
        staysEnded.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [staysEnded], timeout: 6), .completed,
                       "Final episode must remain ended beyond the auto-advance countdown")
        XCTAssertFalse(app.buttons["playback-next-now"].exists)
        XCTAssertFalse(app.staticTexts["playback-next-countdown"].exists)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("HLS 테스트 시즌 · 2화"))
        closePlayback(app)
    }

    func testRealHLSEpisodeProgressRestoresIndependently() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_REAL_HLS"] == "1",
                          "External HLS integration is opt-in; run check-hls-episodes-mac.sh")
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=hls-episodes-\(UUID())"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        openHLSEpisode(1, in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-forward"], in: app)
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: app.buttons["playback-forward"])
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 15), .completed)
        openHLSEpisode(2, in: app)
        XCTAssertFalse(app.staticTexts["playback-resumed"].exists)
        openHLSEpisode(1, in: app)
        XCTAssertTrue(app.staticTexts["playback-resumed"].waitForExistence(timeout: 10))
        closePlayback(app)
    }

    func testDemoEpisodesAdvanceAndStopAtFinalEpisode() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        selectEpisodeDemo(app)
        for number in [2, 3] {
            finishEpisode(app)
            XCTAssertTrue(app.staticTexts["playback-next-countdown"].waitForExistence(timeout: 5))
            let advanced = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", "\(number)화"),
                object: app.staticTexts["playback-source-label"])
            XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 20), .completed)
            expectPlayback("재생 중", in: app)
        }
        finishEpisode(app)
        XCTAssertFalse(app.staticTexts["playback-next-countdown"].exists)
        XCTAssertFalse(app.buttons["playback-next-now"].exists)
        closePlayback(app)
    }

    func testDemoEpisodeCountdownCancellationAndManualAdvance() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        selectEpisodeDemo(app)
        finishEpisode(app)
        // Both timed actions must be reachable without scrolling the short
        // landscape viewport while the real ten-second countdown is running.
        XCTAssertTrue(app.buttons["playback-next-cancel"].isHittable)
        XCTAssertTrue(app.buttons["playback-next-now"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["playback-next-cancel"].frame.height, 44)
        tap(app.buttons["playback-next-cancel"], in: app)
        let unwantedAdvance = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "2화"),
            object: app.staticTexts["playback-source-label"])
        unwantedAdvance.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [unwantedAdvance], timeout: 11), .completed)
        XCTAssertFalse(app.staticTexts["playback-next-countdown"].exists)
        expectPlayback("재생 완료", in: app)
        tap(app.buttons["playback-next-now"], in: app)
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("2화"), "Expected episode 2, actual: \(app.staticTexts["playback-source-label"].label)")
        closePlayback(app)
    }

    private func audioRoleRow(_ role: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "playback-audio-audio-", role)).firstMatch
    }

    private func expectAudioSelected(_ row: XCUIElement, in app: XCUIApplication, name: String) {
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", "선택됨"), object: row)
        guard XCTWaiter.wait(for: [selected], timeout: 30) == .completed else {
            captureFailure(app, name: name)
            XCTFail("Expected selected native audio row: \(name)")
            return
        }
        XCTAssertFalse(app.buttons["playback-audio-retry"].exists,
                       "Audio-list load failure cannot count as successful fallback")
    }

    func testRealHLSAudioRoleFallbackRestoresDVSAndIsolatesProfiles() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_REAL_HLS"] == "1",
                          "Run check-hls-audio-fallback-mac.sh with internet connected")
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        openPlaybackSource("apple-trailer-audio-v1", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        let dvs = audioRoleRow("화면 해설", in: app)
        guard dvs.waitForExistence(timeout: 30) else {
            captureFailure(app, name: "HLS DVS fixture unavailable")
            XCTFail("The real HLS fixture must expose a playable audio-description track")
            return
        }
        tap(dvs, in: app)
        expectAudioSelected(dvs, in: app, name: "DVS selection")
        tap(app.buttons["playback-subtitle-done"], in: app)

        // This other Apple master contains ordinary English but no DVS rendition.
        // Nothing is removed from AVMediaSelectionGroup by a test launch flag.
        openPlaybackSource("apple-bipbop-standard-v1", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        let fallback = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", "저장된 오디오 종류가 없어"),
            object: app.staticTexts["playback-audio-message"])
        guard XCTWaiter.wait(for: [fallback], timeout: 30) == .completed else {
            captureFailure(app, name: "Native HLS audio-role fallback missing")
            XCTFail("Expected same-language role fallback; inspect track list and external fixture")
            return
        }
        expectAudioSelected(audioRoleRow("일반 음성", in: app), in: app, name: "Standard audio fallback")
        XCTAssertFalse(audioRoleRow("화면 해설", in: app).exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        expectPlayback("재생 중", in: app)

        openPlaybackSource("apple-trailer-audio-v1", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        expectAudioSelected(audioRoleRow("화면 해설", in: app), in: app, name: "DVS restored after fallback")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        app.terminate()
        app.launch() // Same unique defaults suite, so restoration is actually exercised.
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        openPlaybackSource("apple-trailer-audio-v1", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        expectAudioSelected(audioRoleRow("화면 해설", in: app), in: app, name: "DVS restored after relaunch")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        app.terminate()
        app.launch()
        choose("adult-b", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        openPlaybackSource("apple-trailer-audio-v1", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        expectAudioSelected(app.buttons["playback-audio-automatic"], in: app, name: "Fresh profile default audio")
        XCTAssertNotEqual(audioRoleRow("화면 해설", in: app).value as? String, "선택됨")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
    }

    func testRealHLSMissingSubtitlePreservesPreference() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_REAL_HLS"] == "1",
                          "External HLS integration is opt-in; run check-hls-tracks-mac.sh")
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨")
        tap(app.buttons["playback-subtitle-done"], in: app)

        // Real AVAsset media-selection loading; no injected missing-language flag.
        openHLSEpisode(1, in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        let message = app.staticTexts["playback-subtitle-message"]
        let fallback = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", "선호 언어는 유지"),
            object: message)
        guard XCTWaiter.wait(for: [fallback], timeout: 30) == .completed else {
            captureFailure(app, name: "Real HLS missing subtitle fallback")
            XCTFail("Expected missing Korean subtitle guidance after real HLS track loading; actual: \(message.exists ? message.label : "no message"). Check network or upstream fixture changes.")
            return
        }
        XCTAssertFalse(app.buttons["playback-subtitle-retry"].exists,
                       "A failed track-list request must not count as missing-language fallback")
        XCTAssertFalse(app.buttons["playback-subtitle-ko"].exists,
                       "The local sidecar track must not leak into HLS playback")
        let selected = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND value == %@", "playback-subtitle-", "선택됨"))
        XCTAssertEqual(selected.count, 1, "Fallback must select one native subtitle or the off option")
        tap(app.buttons["playback-subtitle-done"], in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)

        // Reopening the bundled source must restore the original preference.
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨",
                       "HLS fallback must not overwrite the profile's stored Korean preference")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
    }

    func testMissingSubtitleFallsBackAndRestoresWithoutChangingOtherProfile() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=track-fallback-\(UUID())",
                               "--ui-test-disable-resume", "--ui-test-missing-korean-episode"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        tap(app.buttons["playback-subtitle-done"], in: app)
        openPlaybackSource("demo-series-episode-2-v1", in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        XCTAssertFalse(app.buttons["playback-subtitle-ko"].exists)
        XCTAssertEqual(app.buttons["playback-subtitle-off"].value as? String, "선택됨")
        XCTAssertTrue(app.staticTexts["playback-subtitle-message"].label.contains("선호 언어는 유지"))
        tap(app.buttons["playback-subtitle-done"], in: app)
        openPlaybackSource("demo-series-episode-3-v1", in: app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        app.terminate()
        app.launch()
        choose("adult-b", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-subtitles"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-off"].value as? String, "선택됨")
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
    }

    private func disableAutomaticCaptionsForManualPreferenceTest(_ app: XCUIApplication) {
        tap(app.buttons["playback-subtitles"], in: app)
        let toggle = app.switches["playback-auto-captions"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String == "1" { tap(toggle, in: app) }
        XCTAssertEqual(toggle.value as? String, "0", "Manual preference tests require automatic captions off")
        tap(app.buttons["playback-subtitle-done"], in: app)
    }

    func testSubtitleSelectionSeekingAndRestoration() {
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.1667)
        guard waitForPausedSeek(app, timePattern: "00:00:0[4-6] / 00:00:30") else { return }
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        let caption = app.staticTexts["playback-caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        tap(app.buttons["playback-forward"], in: app)
        guard waitForPausedSeek(app, timePattern: "00:00:1[4-6] / 00:00:30") else { return }
        expectation(for: NSPredicate(format: "label == %@", "자막 선택에서 언어를 바꿀 수 있습니다."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-backward"], in: app)
        guard waitForPausedSeek(app, timePattern: "00:00:0[4-6] / 00:00:30") else { return }
        expectation(for: NSPredicate(format: "label == %@", "StreamLab 데모 영상입니다."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-en"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-en"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "Welcome to the StreamLab demo."), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-off"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-off"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        XCTAssertFalse(caption.exists)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-ko"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-ko"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "한국어 · 데모")
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        closePlayback(app)
    }

    func testLanguagePreferenceSurvivesEpisodesRelaunchAndProfileSwitch() {
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        selectEpisodeDemo(app)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-en"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-en"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        finishEpisode(app)
        // The countdown can finish while XCTest resolves/scrolls the transient button.
        // This test verifies language continuity through an actual episode transition;
        // the separate cancellation/manual-advance test owns the "play now" button.
        let secondEpisode = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS %@", "연속 재생 데모 · 2화"),
            object: app.staticTexts["playback-source-label"])
        guard XCTWaiter.wait(for: [secondEpisode], timeout: 15) == .completed else {
            captureFailure(app, name: "Language test did not advance to episode 2")
            XCTFail("Episode 1 must automatically advance to episode 2 before checking language persistence")
            return
        }
        expectPlayback("재생 중", in: app)
        XCTAssertTrue(app.staticTexts["playback-source-label"].label.contains("2화"), "Expected episode 2, actual: \(app.staticTexts["playback-source-label"].label)")
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "English · Demo")
        closePlayback(app)
        app.terminate()
        app.launch() // same defaults suite, fresh process
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "English · Demo")
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-off"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-off"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "끄기")
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-en"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-en"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        app.terminate()
        app.launch()
        choose("adult-b", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        disableAutomaticCaptionsForManualPreferenceTest(app)
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "끄기")
        tap(app.buttons["playback-subtitles"], in: app)
        let message = app.staticTexts["playback-audio-message"]
        for _ in 0..<3 {
            if message.exists { break }
            let audioColumn = app.scrollViews["playback-audio-list"]
            if audioColumn.exists { audioColumn.swipeUp() }
            else { app.scrollViews["playback-language-list"].swipeUp() }
        }
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertEqual(message.label, "이 데모 영상은 무음입니다.")
        tap(app.buttons["playback-subtitle-done"], in: app)
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
        exercisePlaybackResumeAfterRelaunch(mockOffline: false)
    }

    func testHLSRestartAndSliderKeepTimeAdvancing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=hls-clock-\(UUID())",
                               "--ui-test-keep-playback-controls"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        openPlaybackSource("apple-bipbop-v1", in: app)
        tap(app.buttons["playback-forward"], in: app)
        expectPlayback("재생 중", in: app)
        closePlayback(app)
        openPlayback(app)
        openPlaybackSource("apple-bipbop-v1", in: app)
        XCTAssertTrue(app.staticTexts["playback-resumed"].waitForExistence(timeout: 10))
        tap(app.buttons["playback-restart"], in: app)
        expectPlayback("재생 중", in: app)
        assertPlaybackClockAdvances(app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0)
        expectPlayback("재생 중", in: app)
        assertPlaybackClockAdvances(app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.15)
        guard waitForPausedSeek(app, timePattern: "00:0[3-5]:[0-5][0-9] / 00:30:00") else { return }
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0)
        guard waitForPausedSeek(app, timePattern: "00:00:0[0-1] / 00:30:00") else { return }
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("재생 중", in: app)
        assertPlaybackClockAdvances(app)
        closePlayback(app)
    }

    func testHLSPlayingSliderMiddleThenBeginningClockAdvances() {
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        openPlaybackSource("apple-bipbop-v1", in: app)
        let slider = app.sliders["playback-position"]
        // Use only the timeline while playing. Never pause or use skip/restart buttons.
        for (target, lower, upper, label) in [(CGFloat(0.5), 850.0, 950.0, "middle"),
                                             (CGFloat(0), 0.0, 15.0, "beginning")] {
            slider.adjust(toNormalizedSliderPosition: target)
            let landed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard app.buttons["playback-toggle"].isEnabled,
                      app.staticTexts["playback-status"].label == "재생 중",
                      let time = self.playbackTimes(app)?.position else { return false }
                return time >= lower && time <= upper
            }, object: nil)
            guard XCTWaiter.wait(for: [landed], timeout: 20) == .completed else {
                captureFailure(app, name: "Playing slider did not land at \(label)")
                XCTFail("Timeline must reach \(label) while remaining in playing state")
                return
            }
            let before = app.staticTexts["playback-time"].label
            assertPlaybackClockAdvances(app)
            let after = app.staticTexts["playback-time"].label
            print("PLAYING_SLIDER \(label): \(before) -> \(after)")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Playing slider \(label): \(before) -> \(after)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTAssertFalse(app.staticTexts["playback-seek-message"].exists)
        }
        closePlayback(app)
    }

    private func assertPlaybackClockAdvances(_ app: XCUIApplication) {
        guard let before = playbackTimes(app)?.position else {
            XCTFail("Playback clock missing")
            return
        }
        let advances = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let now = self.playbackTimes(app)?.position else { return false }
            return now >= before + 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [advances], timeout: 12), .completed,
                       "Playback time must advance after seek, not remain at its optimistic target")
    }

    func testPlaybackResumeWithOfflineMutationTransport() {
        exercisePlaybackResumeAfterRelaunch(mockOffline: true)
    }

    private func exercisePlaybackResumeAfterRelaunch(mockOffline: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=streamlab-uitest-\(UUID())",
                               "--ui-test-keep-playback-controls"]
        if mockOffline { app.launchArguments.append("--ui-test-mutation-offline") }
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.5)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-toggle"])
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:1[3-7] / 00:00:30"), evaluatedWith: app.staticTexts["playback-time"])
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
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:(1[3-9]|2[0-4]) / 00:00:30"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        tap(app.buttons["playback-restart"], in: app)
        expectation(for: NSPredicate(format: "label == %@", "00:00:00 / 00:00:30"), evaluatedWith: app.staticTexts["playback-time"])
        waitForExpectations(timeout: 5)
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCTAssertFalse(app.staticTexts["playback-resumed"].exists)
        closePlayback(app)
    }

    func testHomeContinueWatchingUsesSavedProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=streamlab-home-uitest-\(UUID())",
                               "--ui-test-keep-playback-controls"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.5)
        let seekReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["playback-toggle"])
        let seekTime = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label MATCHES %@", "00:00:1[3-7] / 00:00:30"), object: app.staticTexts["playback-time"])
        guard XCTWaiter.wait(for: [seekReady, seekTime], timeout: 5) == .completed else {
            let time = app.staticTexts["playback-time"]
            let slider = app.sliders["playback-position"]
            let actual = time.exists ? time.label : "missing"
            let value = slider.exists ? String(describing: slider.value) : "missing"
            captureFailure(app, name: "Home progress initial seek")
            XCTFail("Expected 13–17 seconds after 50% seek; time=\(actual), slider=\(value)")
            return
        }
        closePlayback(app)
        back(app)
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "continue-", "continue-retry")).firstMatch
        for _ in 0..<5 {
            if card.exists && card.isHittable { break }
            app.scrollViews["home-catalog"].swipeUp()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let returnFrame = app.frame
        tap(card, in: app)
        guard app.buttons["playback-close"].waitForExistence(timeout: 10) else {
            print("Continue Watching presentation failure: \(app.debugDescription)")
            captureFailure(app, name: "Continue Watching did not open playback")
            XCTFail("Continue Watching card must present the player")
            return
        }
        guard app.staticTexts["playback-resumed"].waitForExistence(timeout: 10) else {
            print("Continue Watching restore failure: \(app.debugDescription)")
            captureFailure(app, name: "Continue Watching missing restored progress")
            XCTFail("Presented player must report restored progress")
            return
        }
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        guard let restoredTime = playbackTimes(app), restoredTime.position >= 13,
              restoredTime.position < restoredTime.duration else {
            captureFailure(app, name: "Continue Watching incorrect restored position")
            XCTFail("Continue Watching must resume from the saved position, not zero")
            return
        }
        tap(app.buttons["playback-close"], in: app)
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["playback-close"])
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "frame == %@", NSValue(cgRect: returnFrame)), object: app)
        guard XCTWaiter.wait(for: [dismissed, restored], timeout: 10) == .completed else {
            captureFailure(app, name: "Home playback orientation restoration")
            XCTFail("Home playback must dismiss and restore its original frame. Expected \(returnFrame), actual \(app.frame)")
            return
        }
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        XCTAssertTrue(app.staticTexts["continue-empty"].waitForExistence(timeout: 10))
        XCTAssertFalse(card.exists)
    }

    private func launch(largeText: Bool = false, slow: Bool = false, keepPlaybackControls: Bool = false, disableAutomaticPiP: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-progress-suite=streamlab-uitest-\(UUID())")
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if slow { app.launchArguments.append("--ui-test-slow-catalog") }
        if keepPlaybackControls { app.launchArguments.append("--ui-test-keep-playback-controls") }
        if disableAutomaticPiP { app.launchArguments.append("--ui-test-disable-automatic-pip") }
        app.launchArguments.append("--ui-test-disable-resume")
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let reveal = app.buttons["playback-reveal-controls"]
        // A single reveal check followed by a 12-second existence wait races
        // the real four-second HUD timer. Recheck reveal while waiting instead.
        var appeared = false
        for _ in 0..<12 {
            if !element.exists && reveal.exists && reveal.isHittable { reveal.tap() }
            if element.waitForExistence(timeout: 1) { appeared = true; break }
        }
        guard appeared else {
            captureFailure(app, name: "Target did not appear")
            XCTFail("Target did not appear: \(element)", file: file, line: line)
            return
        }
        // Cache before auto-hide; querying identifier on a missing element throws in XCTest.
        let targetID = element.identifier
        let playerTarget = targetID.hasPrefix("playback-") && targetID != "playback-open"
        for _ in 0..<8 {
            // Auto-hide can occur during snapshot queries; re-resolve on every attempt.
            if !element.exists && reveal.exists && reveal.isHittable { reveal.tap() }
            if element.exists && element.isHittable { break }
            let controls = app.descendants(matching: .any).matching(identifier: "playback-controls-scroll").firstMatch
            if playerTarget {
                guard controls.exists, element.exists else {
                    // A new loop rechecks the reveal button. Still bounded by eight attempts.
                    continue
                }
                let viewport = controls.frame.intersection(app.frame)
                let target = element.frame
                guard !viewport.isNull, !viewport.isEmpty, !target.isEmpty else {
                    captureFailure(app, name: "Player controls empty frame")
                    XCTFail("Player controls or target have no usable frame", file: file, line: line)
                    return
                }
                // A container need not be a hittable accessibility element to scroll.
                // Use only coordinates within its observed viewport, never the detail beneath.
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: viewport.midY - app.frame.minY))
                let distance = min(180, viewport.height * 0.35)
                if target.midY < viewport.minY + 24 {
                    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
                } else if target.midY > viewport.maxY - 24 {
                    start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)))
                }
                else {
                    // A visible but unhittable button may still be transitioning.
                    // Do not guess a swipe direction or send gestures to the underlying detail.
                    let hittable = XCTNSPredicateExpectation(
                        predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
                    guard XCTWaiter.wait(for: [hittable], timeout: 1) == .completed else {
                        continue
                    }
                    break
                }
            } else { app.swipeUp() }
        }
        guard element.exists && element.isHittable else {
            captureFailure(app, name: "Unreachable " + targetID)
            XCTFail("Target is not hittable after bounded reveal attempts: \(targetID)", file: file, line: line)
            return
        }
        element.tap()
    }

    private func enterDemoIfNeeded(_ app: XCUIApplication) {
        let profile = app.buttons["profile-adult-a"]
        let signIn = app.buttons["demo-sign-in"]
        let ready = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@", ["profile-adult-a", "demo-sign-in", "hero-detail"])).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 15))
        if signIn.exists {
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: signIn)
            waitForExpectations(timeout: 15)
            tap(signIn, in: app)
            if !profile.waitForExistence(timeout: 15) {
                let error = app.staticTexts["logout-error"]
                let reason = error.exists ? error.label : "No authentication error label; inspect screenshot/hierarchy"
                captureFailure(app, name: "Demo sign-in failed")
                XCTFail("Demo sign-in did not reach profiles: \(reason)")
            }
        }
    }

    private func choose(_ id: String, in app: XCUIApplication) {
        enterDemoIfNeeded(app)
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
        // The loading title exists before loading and push transitions complete.
        let loaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"),
            object: app.buttons["detail-retry"])
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: app.navigationBars.buttons["BackButton"])
        guard XCTWaiter.wait(for: [loaded, ready], timeout: 12) == .completed else {
            captureFailure(app, name: "Detail entry not ready")
            XCTFail("Detail must finish loading and expose its back button")
            return
        }
    }

    private func openPlayback(_ app: XCUIApplication) {
        playbackReturnFrame = app.frame
        tap(app.buttons["playback-open"], in: app)
    }

    // A seek publishes its target optimistically. Check completion before time/caption.
    // The allowance exceeds the engine's eight-second watchdog so a stalled seek
    // reports a seek failure, without retrying it or accepting a cleared spinner alone.
    private func waitForPausedSeek(_ app: XCUIApplication, timePattern: String) -> Bool {
        let time = app.staticTexts["playback-time"]
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND value == %@", "재생 위치 확인됨"), object: time)
        guard XCTWaiter.wait(for: [completed], timeout: 10) == .completed else {
            captureFailure(app, name: "Seek did not complete before caption check")
            XCTFail("Seek did not complete successfully; inspect playback-seek-message and playback-time")
            return false
        }
        let position = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@ AND label MATCHES %@", "재생 위치 확인됨", timePattern), object: time)
        guard XCTWaiter.wait(for: [position], timeout: 2) == .completed else {
            captureFailure(app, name: "Seek completed at unexpected position")
            XCTFail("Completed seek must reach \(timePattern); actual: \(time.label)")
            return false
        }
        XCTAssertFalse(app.descendants(matching: .any)["playback-loading"].exists)
        XCTAssertFalse(app.staticTexts["playback-seek-message"].exists)
        XCTAssertEqual(app.staticTexts["playback-status"].label, "일시 정지")
        return true
    }

    private func closePlayback(_ app: XCUIApplication, returningToDownloads: Bool = false) {
        tap(app.buttons["playback-close"], in: app)
        // Cover dismissal and scene rotation are separate transitions. Neither a tap
        // returning nor the underlying detail existing proves both have completed.
        var transitions = [
            XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["playback-close"])
        ]
        if let frame = playbackReturnFrame {
            print("[PlaybackReturn] Waiting for original window frame: \(frame)")
            transitions.append(XCTNSPredicateExpectation(predicate: NSPredicate(format: "frame == %@", NSValue(cgRect: frame)), object: app))
        }
        guard XCTWaiter.wait(for: transitions, timeout: 10) == .completed else {
            captureFailure(app, name: "Detail playback orientation restoration")
            XCTFail("Detail playback must dismiss and restore its original frame. Expected \(String(describing: playbackReturnFrame)), actual \(app.frame), close exists: \(app.buttons["playback-close"].exists)")
            return
        }
        if returningToDownloads {
            XCTAssertTrue(app.staticTexts["downloads-profile"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["downloads-profile"].isHittable)
            return
        }
        XCTAssertTrue(app.staticTexts["detail-title"].waitForExistence(timeout: 5))
        let backButton = app.navigationBars.buttons["BackButton"]
        expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: backButton)
        waitForExpectations(timeout: 5)
    }

    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons["BackButton"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: button)
        guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed else {
            captureFailure(app, name: "Detail back button timeout")
            XCTFail("Detail back button did not become hittable")
            return
        }
        button.tap()
        // Fail at the actual navigation boundary instead of cascading into profile taps.
        let departed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["detail-title"])
        guard XCTWaiter.wait(for: [departed], timeout: 5) == .completed else {
            captureFailure(app, name: "Detail remained after back tap")
            XCTFail("Detail remained after one back tap; navigation was not retried")
            return
        }
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

    func testDemoLoginAtMaximumTextSize() {
        let app = launch(largeText: true)
        let scroll = app.scrollViews["demo-sign-in-scroll"]
        let signIn = app.buttons["demo-sign-in"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["demo-sign-in-description"].exists)
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if scroll.frame.intersection(app.frame).contains(signIn.frame) && signIn.isHittable { break }
            scroll.swipeUp()
        }
        guard scroll.frame.intersection(app.frame).contains(signIn.frame), signIn.isHittable else {
            captureFailure(app, name: "Maximum text demo sign-in unreachable")
            XCTFail("Demo sign-in must be fully visible and reachable at maximum text size")
            return
        }
        XCTAssertGreaterThanOrEqual(signIn.frame.height, 44)
        enterDemoIfNeeded(app)
        XCTAssertTrue(app.buttons["profile-adult-a"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["logout-error"].exists)
    }

    func testDemoLoginRestoresAndLogoutSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=demo-auth-\(UUID())"]
        app.launch()
        let signIn = app.buttons["demo-sign-in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["profile-adult-a"].exists)
        enterDemoIfNeeded(app)
        app.terminate()
        app.launch()
        // Do not use choose's sign-in helper here: restoration must work unaided.
        XCTAssertTrue(app.buttons["profile-adult-a"].waitForExistence(timeout: 15))
        XCTAssertFalse(signIn.exists)
        choose("adult-a", in: app)
        tap(app.buttons["account-logout"], in: app)
        let dialog = app.sheets["로그아웃하면 이 기기의 모든 프로필 기록이 삭제됩니다."]
        tap(dialog.buttons.matching(identifier: "confirm-logout").firstMatch, in: app)
        XCTAssertTrue(signIn.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: signIn)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(app.staticTexts["logout-error"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(signIn.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["profile-adult-a"].exists)
        enterDemoIfNeeded(app)
        XCTAssertFalse(app.staticTexts["logout-error"].exists)
    }

    func testColdLaunchAndRelaunchShowProfiles() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=cold-demo-\(UUID())"]
        for _ in 0..<2 {
            app.launch()
            enterDemoIfNeeded(app)
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
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:(1[0-9]|2[0-9]|30) / 00:00:30"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        closePlayback(app)
        back(app)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
    }

    private func expectPlayback(_ status: String, in app: XCUIApplication) {
        // Playback continues when the HUD is hidden. Its real accessible reveal
        // action carries the current state; observing it must not toggle the HUD.
        let observed = app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier == %@ AND label == %@) OR (identifier == %@ AND value == %@)",
            "playback-status", status, "playback-reveal-controls", status)).firstMatch
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"), object: observed)
        guard XCTWaiter.wait(for: [expected], timeout: 15) == .completed else {
            let label = app.staticTexts["playback-status"]
            let reveal = app.buttons["playback-reveal-controls"]
            let actual = label.exists ? label.label :
                (reveal.exists ? (reveal.value as? String ?? "hidden state unavailable") : "status element missing")
            captureFailure(app, name: "Playback status mismatch")
            XCTFail("Expected playback status: \(status); actual: \(actual)")
            return
        }
    }

    func testCustomPlaybackLandscapeAndControls() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        // Geometry/seek assertions need a stable HUD. Production auto-hide is
        // exercised separately without this visibility-only launch option.
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCTAssertGreaterThan(app.frame.width, app.frame.height, "Player should request landscape on a full-screen iPhone.")
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        let slider = app.sliders["playback-position"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        let time = app.staticTexts["playback-time"]
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:1[3-7] / 00:00:30"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        let toggle = app.buttons["playback-toggle"]
        XCTAssertEqual(toggle.frame.midX, app.frame.midX, accuracy: 24)
        XCTAssertEqual(toggle.frame.midY, app.frame.midY, accuracy: 24)
        for id in ["playback-backward", "playback-forward"] {
            XCTAssertEqual(app.buttons[id].frame.midY, toggle.frame.midY, accuracy: 2)
        }
        // Paused playback makes the expected +/-10 seconds deterministic.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).doubleTap()
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:2[3-7] / 00:00:30"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).doubleTap()
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:1[3-7] / 00:00:30"), evaluatedWith: time)
        waitForExpectations(timeout: 10)
        expectPlayback("일시 정지", in: app)
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
        // Resume text must not move essential tools below the landscape viewport.
        for id in ["playback-close", "playback-subtitles", "playback-fit", "playback-rotate"] {
            let control = app.buttons[id]
            XCTAssertTrue(control.isHittable, "\(id) must be reachable without scrolling")
            XCTAssertTrue(app.frame.contains(control.frame), "\(id) must be fully onscreen")
        }
        closePlayback(app)
    }

    func testPlaybackControlsHideAndRevealWithoutChangingPlayback() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        let reveal = app.buttons["playback-reveal-controls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 10), "Production HUD must hide after inactivity.")
        XCTAssertEqual(reveal.value as? String, "재생 중")
        XCTAssertFalse(app.buttons["playback-toggle"].exists)
        reveal.tap()
        XCTAssertTrue(app.buttons["playback-toggle"].waitForExistence(timeout: 2))
        expectPlayback("재생 중", in: app)
        app.terminate()
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

    func testMediaResetRequiresUserRetryAndRecreatesPlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=reset-\(UUID())",
                               "--ui-test-disable-resume", "--ui-test-media-reset-once"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        let alert = app.alerts["영상을 불러올 수 없습니다"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "미디어 서비스")).firstMatch.exists)
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "남은 재시도: 3회")).firstMatch.exists)
        alert.buttons["재시도"].tap()
        expectPlayback("재생 중", in: app)
        XCTAssertFalse(alert.exists)
        closePlayback(app)
    }

    func testPlaybackRetryBudgetStopsAfterThreeRetries() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=retry-budget-\(UUID())",
                               "--ui-test-disable-resume", "--ui-test-resource-always-missing"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        for remaining in [3, 2, 1] {
            let count = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "남은 재시도: \(remaining)회"),
                object: app.staticTexts["playback-retry-remaining"])
            XCTAssertEqual(XCTWaiter.wait(for: [count], timeout: 10), .completed)
            tap(app.buttons["playback-retry"], in: app)
        }
        let exhausted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "남은 재시도: 0회"),
            object: app.staticTexts["playback-retry-remaining"])
        XCTAssertEqual(XCTWaiter.wait(for: [exhausted], timeout: 10), .completed)
        XCTAssertFalse(app.buttons["playback-retry"].isEnabled)
        closePlayback(app)
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

    func testMockDevicesRestorePlaybackAndRestart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=sync-\(UUID().uuidString)"]
        app.launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        func selectDevice(_ device: String) {
            tap(app.buttons["sync-device-\(device)"], in: app)
            let open = app.buttons["playback-open"]
            for _ in 0..<12 {
                if open.exists && open.isHittable { break }
                app.scrollViews["detail-scroll"].swipeDown()
            }
        }
        selectDevice("A")
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        tap(app.buttons["playback-forward"], in: app)
        guard waitForPausedSeek(app, timePattern: "00:00:1[0-9].*") else { return }
        closePlayback(app)
        selectDevice("B")
        openPlayback(app)
        XCTAssertTrue(app.staticTexts["playback-resumed"].waitForExistence(timeout: 12))
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        XCTAssertTrue(app.staticTexts["playback-time"].label.hasPrefix("00:00:1"))
        tap(app.buttons["playback-restart"], in: app)
        guard waitForPausedSeek(app, timePattern: "00:00:00.*") else { return }
        closePlayback(app)
        selectDevice("A")
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        XCTAssertFalse(app.staticTexts["playback-resumed"].exists)
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

    func testPlaybackContinuesAfterBackground() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STREAMLAB_TEST_REAL_HLS"] == "1",
                          "Requires real HLS audio; run check-background-playback-mac.sh")
        let app = launch(keepPlaybackControls: true, disableAutomaticPiP: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        openPlaybackSource("apple-trailer-audio-v1", in: app)
        expectPlayback("재생 중", in: app)
        let before = try XCTUnwrap(playbackTimes(app))
        XCUIDevice.shared.press(.home)
        // Real elapsed background time is the behavior under test, not a UI readiness wait.
        Thread.sleep(forTimeInterval: 4)
        app.activate()
        expectPlayback("재생 중", in: app)
        let after = try XCTUnwrap(playbackTimes(app))
        XCTAssertGreaterThanOrEqual(after.position - before.position, 3)
        closePlayback(app)
    }

    func testPausedPlaybackStaysPausedAfterBackground() throws {
        let app = launch(keepPlaybackControls: true)
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        let before = try XCTUnwrap(playbackTimes(app))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 4)
        app.activate()
        expectPlayback("일시 정지", in: app)
        let after = try XCTUnwrap(playbackTimes(app))
        XCTAssertEqual(after.position, before.position, accuracy: 1)
        closePlayback(app)
    }

    private func selectHomeCategory(_ name: String, in app: XCUIApplication) {
        let button = app.buttons["home-category-\(name)"]
        let picker = app.scrollViews["home-category-scroll"]
        guard picker.waitForExistence(timeout: 5), button.waitForExistence(timeout: 5) else {
            captureFailure(app, name: "Home category picker missing")
            XCTFail("Category picker and requested button must exist")
            return
        }
        // A partially clipped chip can be hittable without its center being visible.
        // Reveal it in the horizontal picker, never by scrolling the whole screen.
        for _ in 0..<4 {
            let viewport = picker.frame.intersection(app.frame)
            let frame = button.frame
            if viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) && button.isHittable { break }
            if frame.midX < viewport.minX { picker.swipeRight() }
            else if frame.midX > viewport.maxX { picker.swipeLeft() }
            else { break }
        }
        guard button.isHittable,
              picker.frame.intersection(app.frame).contains(CGPoint(x: button.frame.midX, y: button.frame.midY)) else {
            captureFailure(app, name: "Home category outside picker viewport")
            XCTFail("Category button must be visible inside its picker")
            return
        }
        button.tap()
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
        selectHomeCategory("나의 리스트", in: app)
        let savedCategory = app.buttons["home-category-나의 리스트"]
        let savedSelected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"), object: savedCategory)
        guard XCTWaiter.wait(for: [savedSelected], timeout: 5) == .completed else {
            print("My List selection failure: \(app.debugDescription)")
            captureFailure(app, name: "My List category not selected")
            XCTFail("My List category must be selected before inspecting saved contents")
            return
        }
        let savedCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@",
                                  "my-list-", "my-list-empty")).firstMatch
        guard savedCard.waitForExistence(timeout: 5) else {
            print("My List contents failure: \(app.debugDescription)")
            captureFailure(app, name: "Saved content missing after category selection")
            XCTFail("Saved content must appear after My List category is selected")
            return
        }
        selectHomeCategory("추천", in: app)
        let recommended = app.buttons["home-category-추천"]
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"), object: recommended)
        guard XCTWaiter.wait(for: [selected], timeout: 5) == .completed else {
            print("Recommendations selection failure: \(app.debugDescription)")
            captureFailure(app, name: "Recommendations category not selected")
            XCTFail("Recommendations must be selected after leaving My List")
            return
        }
        XCTAssertTrue(saved.waitForExistence(timeout: 5),
                      "Returning to recommendations must recreate the hero action")
        // Reveal the action within the newly created category scroll view.
        let home = app.scrollViews["home-catalog"]
        for _ in 0..<5 {
            if saved.exists && saved.isHittable { break }
            home.swipeDown()
        }
        for _ in 0..<5 {
            if saved.exists && saved.isHittable { break }
            home.swipeUp()
        }
        guard saved.exists && saved.isHittable else {
            captureFailure(app, name: "Hero My List unreachable after category change")
            XCTFail("Hero My List must remain reachable after returning to recommendations")
            return
        }
        tap(saved, in: app)
        XCTAssertEqual(saved.value as? String, "추가 안 됨")
    }

    func testLogoutClearsAllProfilesAndStaysSignedOutAfterRelaunch() {
        exerciseAccountLogout(mockOffline: false)
    }

    func testLogoutClearsPendingOfflineChanges() {
        exerciseAccountLogout(mockOffline: true)
    }

    private func exerciseAccountLogout(mockOffline: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=logout-\(UUID())",
                               "--ui-test-keep-playback-controls"]
        if mockOffline { app.launchArguments.append("--ui-test-mutation-offline") }
        app.launch()
        choose("adult-a", in: app)
        let saved = app.buttons["hero-my-list"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.value as? String, "추가 안 됨")
        tap(saved, in: app)
        XCTAssertEqual(saved.value as? String, "추가됨")
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        tap(app.buttons["playback-toggle"], in: app)
        expectPlayback("일시 정지", in: app)
        app.sliders["playback-position"].adjust(toNormalizedSliderPosition: 0.5)
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["playback-toggle"])
        expectation(for: NSPredicate(format: "label MATCHES %@", "00:00:1[3-7] / 00:00:30"), evaluatedWith: app.staticTexts["playback-time"])
        // PlaybackModel permits an 8-second seek watchdog before recovering controls.
        // Allow that recovery plus AX polling; keep the target-position assertion above.
        waitForExpectations(timeout: 12)
        closePlayback(app)
        back(app)
        let continueCard = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH %@ AND identifier != %@", "continue-", "continue-retry")).firstMatch
        for _ in 0..<5 {
            if continueCard.exists { break }
            app.scrollViews["home-catalog"].swipeUp()
        }
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5), "Establish saved progress before logout")
        app.tabBars.buttons["검색"].tap()
        let field = app.textFields["catalog-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("액션\n")
        tap(app.buttons["clear-search"], in: app)
        XCTAssertTrue(app.buttons["recent-search-term-액션"].waitForExistence(timeout: 5))
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        app.tabBars.buttons["홈"].tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        tap(saved, in: app)
        XCTAssertEqual(saved.value as? String, "추가됨")
        app.tabBars.buttons["검색"].tap()
        field.tap()
        field.typeText("드라마\n")
        tap(app.buttons["clear-search"], in: app)
        XCTAssertTrue(app.buttons["recent-search-term-드라마"].waitForExistence(timeout: 5))
        tap(app.buttons["account-logout"], in: app)
        let logoutDialog = app.sheets["로그아웃하면 이 기기의 모든 프로필 기록이 삭제됩니다."]
        XCTAssertTrue(logoutDialog.waitForExistence(timeout: 5))
        // SwiftUI exposes the confirmation action as nested AX buttons on some iOS versions.
        // Scope to the visible dialog and select the first representation of that action.
        let confirmLogout = logoutDialog.buttons.matching(identifier: "confirm-logout").firstMatch
        tap(confirmLogout, in: app)
        let signIn = app.buttons["demo-sign-in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: signIn)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.staticTexts["logout-error"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["profile-adult-a"].exists)
        tap(signIn, in: app)
        for profile in ["adult-a", "adult-b"] {
            choose(profile, in: app)
            app.tabBars.buttons["홈"].tap()
            XCTAssertTrue(saved.waitForExistence(timeout: 5))
            XCTAssertEqual(saved.value as? String, "추가 안 됨")
            let emptyProgress = app.staticTexts["continue-empty"]
            for _ in 0..<5 {
                if emptyProgress.exists { break }
                app.scrollViews["home-catalog"].swipeUp()
            }
            XCTAssertTrue(emptyProgress.waitForExistence(timeout: 5))
            app.tabBars.buttons["검색"].tap()
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["recent-search-clear-all"].exists)
            tap(app.buttons["switch-profile"], in: app)
        }
        // A fresh session must still persist changes after cleanup (no stale rejection).
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        field.tap()
        field.typeText("새 검색\n")
        tap(app.buttons["clear-search"], in: app)
        XCTAssertTrue(app.buttons["recent-search-term-새 검색"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(app.buttons["recent-search-term-새 검색"].waitForExistence(timeout: 5))
    }

    func testRecentSearchesPersistAndIsolateProfiles() {
        exerciseRecentSearchHistory(mockOffline: false)
    }

    func testRecentSearchesPersistWithOfflineMutationTransport() {
        exerciseRecentSearchHistory(mockOffline: true)
    }

    private func exerciseRecentSearchHistory(mockOffline: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-progress-suite=recent-search-\(UUID())"]
        if mockOffline { app.launchArguments.append("--ui-test-mutation-offline") }
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        let field = app.textFields["catalog-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("액션")
        tap(app.buttons["clear-search"], in: app)
        XCTAssertFalse(app.buttons["recent-search-term-액션"].exists,
                       "Typing without submission must not create history")
        field.tap()
        field.typeText("액션\n")
        tap(app.buttons["clear-search"], in: app)
        let action = app.buttons["recent-search-term-액션"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        tap(action, in: app)
        XCTAssertEqual(field.value as? String, "액션")
        tap(app.buttons["clear-search"], in: app)
        field.tap()
        field.typeText("드라마\n")
        tap(app.buttons["clear-search"], in: app)
        XCTAssertTrue(app.buttons["recent-search-term-드라마"].waitForExistence(timeout: 5))
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-b", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recent-search-clear-all"].exists)
        XCTAssertFalse(action.exists)
        tap(app.buttons["switch-profile"], in: app)
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        tap(app.buttons["recent-search-delete-액션"], in: app)
        XCTAssertFalse(action.exists)
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(app.buttons["recent-search-term-드라마"].waitForExistence(timeout: 5))
        XCTAssertFalse(action.exists)
        tap(app.buttons["recent-search-clear-all"], in: app)
        XCTAssertFalse(app.buttons["recent-search-term-드라마"].exists)
        app.terminate()
        app.launch()
        choose("adult-a", in: app)
        app.tabBars.buttons["검색"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["recent-search-clear-all"].exists)
        XCTAssertFalse(app.staticTexts["recent-search-error"].exists)
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
            print("[NavigationSoak] cycle=\(cycle + 1)/\(cycles) time=\(Date())")
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
        guard scroll.waitForExistence(timeout: 5) else {
            captureFailure(app, name: "Missing detail scroll container or checkpoint")
            XCTFail("Missing detail scroll container or checkpoint; see captured hierarchy")
            return false
        }
        // Offscreen SwiftUI sections may not yet expose their descendants.
        // Materialize inside the known scroll view before querying a target frame.
        for _ in 0..<8 where !element.exists { scroll.swipeUp() }
        for _ in 0..<8 where !element.exists { scroll.swipeDown() }
        guard element.exists else {
            captureFailure(app, name: "Missing detail checkpoint after scrolling")
            XCTFail("Detail checkpoint did not appear after bounded scrolling")
            return false
        }

        // Episode descriptions can exceed 5,500pt at AX5. Keep a finite budget
        // large enough to reach the footer; full visibility/hit checks stay unchanged.
        let maximumAttempts = 24
        for attempt in 0...maximumAttempts {
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
            guard attempt < maximumAttempts, viewport.width > 0, viewport.height > 80 else { break }

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

