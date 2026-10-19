import XCTest
import Foundation
import StreamLabDomain
import StreamLabPresentation

final class MuteCaptionPolicyTests: XCTestCase {
    @MainActor
    func testOptionPersistsAndIsolatesProfiles() throws {
        let name = "mute-captions-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        first.setCaptionsWhenMuted(false)
        XCTAssertEqual(PlaybackLanguageStore(profileID: "a", defaults: defaults).preferences.captionsWhenMuted, false)
        XCTAssertTrue(PlaybackLanguageStore(profileID: "b", defaults: defaults).preferences.captionsWhenMuted ?? true)
        XCTAssertEqual(first.preferences.subtitles, .off)
    }

    @MainActor
    func testLegacyPreferencesDecodeWithOptionEnabled() throws {
        let legacy = Data(#"{"subtitles":{"off":{}},"audio":{"automatic":{}}}"#.utf8)
        let value = try JSONDecoder().decode(PlaybackLanguageStore.Preferences.self, from: legacy)
        XCTAssertTrue(value.captionsWhenMuted ?? true)
        XCTAssertEqual(value.subtitles, .off)
    }

    func testMuteEnablesAndUnmuteRestores() {
        var policy = MuteCaptionPolicy()
        XCTAssertEqual(policy.update(isMuted: true, enabled: true, selected: "off", candidate: "ko"), "ko")
        XCTAssertNil(policy.update(isMuted: true, enabled: true, selected: "ko", candidate: "en"))
        XCTAssertEqual(policy.update(isMuted: false, enabled: true, selected: "ko", candidate: "ko"), "off")
    }

    func testManualChoiceWinsUntilNextMute() {
        var policy = MuteCaptionPolicy()
        _ = policy.update(isMuted: true, enabled: true, selected: "off", candidate: "ko")
        policy.userSelected(isMuted: true)
        XCTAssertNil(policy.update(isMuted: true, enabled: true, selected: "off", candidate: "ko"))
        XCTAssertNil(policy.update(isMuted: false, enabled: true, selected: "en", candidate: "ko"))
        XCTAssertEqual(policy.update(isMuted: true, enabled: true, selected: "off", candidate: "ko"), "ko")
    }

    func testDisabledAndAlreadySelectedRemainUntouched() {
        var policy = MuteCaptionPolicy()
        XCTAssertNil(policy.update(isMuted: true, enabled: false, selected: "off", candidate: "ko"))
        XCTAssertNil(policy.update(isMuted: true, enabled: true, selected: "en", candidate: "ko"))
        XCTAssertNil(policy.update(isMuted: false, enabled: true, selected: "en", candidate: "ko"))
    }

    func testLateTrackArrivalAndDisableRestore() {
        var policy = MuteCaptionPolicy()
        XCTAssertNil(policy.update(isMuted: true, enabled: true, selected: "off", candidate: nil))
        XCTAssertEqual(policy.update(isMuted: true, enabled: true, selected: "off", candidate: "ko"), "ko")
        XCTAssertEqual(policy.update(isMuted: true, enabled: false, selected: "ko", candidate: "ko"), "off")
    }
}
