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

    func testSubtitleSelectionSeekingAndRestoration() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
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
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "한국어 · 데모")
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        closePlayback(app)
    }

    func testLanguagePreferenceSurvivesEpisodesRelaunchAndProfileSwitch() {
        let app = launch()
        choose("adult-a", in: app)
        openHomeDetail(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
        selectEpisodeDemo(app)
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-en"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-en"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        finishEpisode(app)
        tap(app.buttons["playback-next-now"], in: app)
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
        XCTAssertEqual(app.buttons["playback-subtitles"].value as? String, "English · Demo")
        tap(app.buttons["playback-subtitles"], in: app)
        tap(app.buttons["playback-subtitle-off"], in: app)
        XCTAssertEqual(app.buttons["playback-subtitle-off"].value as? String, "선택됨")
        XCTAssertTrue(app.buttons["playback-subtitle-done"].exists)
        tap(app.buttons["playback-subtitle-done"], in: app)
        closePlayback(app)
        openPlayback(app)
        expectPlayback("재생 중", in: app)
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
            if reveal.exists && reveal.isHittable { reveal.tap() }
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
            if reveal.exists && reveal.isHittable { reveal.tap() }
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

    private func closePlayback(_ app: XCUIApplication) {
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
        guard scroll.waitForExistence(timeout: 5), element.waitForExistence(timeout: 5) else {
            captureFailure(app, name: "Missing detail scroll container or checkpoint")
            XCTFail("Missing detail scroll container or checkpoint; see captured hierarchy")
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

