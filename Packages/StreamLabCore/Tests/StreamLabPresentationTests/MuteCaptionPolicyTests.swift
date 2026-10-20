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

    @MainActor
    func testEnglishSurvivesOffAndReloadWithoutCrossingProfiles() throws {
        let name = "mute-language-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        store.setSubtitles(.language("en"))
        store.setSubtitles(.off)
        let restored = PlaybackLanguageStore(profileID: "a", defaults: defaults).preferences
        XCTAssertEqual(restored.subtitles, .off)
        let preference = restored.mutedSubtitlePreference(deviceLanguage: "ko")
        XCTAssertEqual(preference, .language("en"))
        XCTAssertEqual(MediaLanguageResolver.index(for: preference, languages: ["ko", "en"],
                                                  defaultIndex: nil, allowsOff: false), 1)
        var policy = MuteCaptionPolicy()
        XCTAssertEqual(policy.update(isMuted: true, enabled: true, selected: "off", candidate: "en"), "en")
        XCTAssertEqual(policy.update(isMuted: false, enabled: true, selected: "en", candidate: "en"), "off")
        XCTAssertEqual(PlaybackLanguageStore(profileID: "b", defaults: defaults).preferences
            .mutedSubtitlePreference(deviceLanguage: "ko"), .language("ko"))
    }

    @MainActor
    func testLegacyEnglishIsRetainedWhenTurnedOff() throws {
        let name = "mute-legacy-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let key = "streamlab.languages.v1." + Data("a".utf8).base64EncodedString()
        let legacy = Data(#"{"subtitles":{"language":{"_0":"en"}},"audio":{"automatic":{}}}"#.utf8)
        defaults.set(legacy, forKey: key)
        let store = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        XCTAssertEqual(store.preferences.subtitles, .language("en"))
        store.setSubtitles(.off)
        XCTAssertEqual(store.preferences.mutedSubtitlePreference(deviceLanguage: "ko"), .language("en"))
        store.invalidate()
        store.setSubtitles(.language("ko"))
        XCTAssertEqual(PlaybackLanguageStore(profileID: "a", defaults: defaults).preferences.lastSubtitleLanguage, "en")
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
