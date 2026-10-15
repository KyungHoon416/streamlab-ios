import XCTest
import StreamLabDomain

final class TrackFallbackTests: XCTestCase {
    func testMissingSubtitleUsesDefaultOrOffAndRequiredTrackCannotBeOff() {
        let saved = MediaLanguagePreference.language("ko")
        XCTAssertNil(MediaLanguageResolver.index(for: saved, languages: ["en"], defaultIndex: nil, allowsOff: true))
        XCTAssertEqual(MediaLanguageResolver.index(for: saved, languages: ["en"], defaultIndex: 0, allowsOff: true), 0)
        XCTAssertEqual(MediaLanguageResolver.index(for: .off, languages: ["en"], defaultIndex: 0, allowsOff: false), 0)
        XCTAssertNil(MediaLanguageResolver.index(for: .off, languages: ["en"], defaultIndex: 0, allowsOff: true))
    }

    func testMissingAudioRoleFallsBackWithinLanguageBeforeOtherLanguage() {
        XCTAssertEqual(AudioPreferenceResolver.index(for: .language("en"), role: .audioDescription,
            languages: ["ko", "en"], roles: [.audioDescription, .standard], defaultIndex: 0), 1)
        XCTAssertEqual(AudioPreferenceResolver.index(for: .language("ko"), role: .standard,
            languages: ["en"], roles: [.standard], defaultIndex: 0), 0)
    }

    func testEmptyPlayableListNeverReturnsAnInvalidIndex() {
        for preference in [MediaLanguagePreference.off, .automatic, .language("ko")] {
            for index in [-1, 0, 99] {
                XCTAssertNil(MediaLanguageResolver.index(for: preference, languages: [], defaultIndex: index, allowsOff: false))
                XCTAssertNil(AudioPreferenceResolver.index(for: preference, role: .audioDescription,
                    languages: [], roles: [], defaultIndex: index))
            }
        }
    }

    func testPreferredTrackReturnsWhenNextItemProvidesItInDifferentOrder() {
        let saved = MediaLanguagePreference.language("en-US")
        XCTAssertEqual(AudioPreferenceResolver.index(for: saved, role: .audioDescription,
            languages: ["ko"], roles: [.standard], defaultIndex: 0), 0)
        XCTAssertEqual(AudioPreferenceResolver.index(for: saved, role: .audioDescription,
            languages: ["en-US", "ko", "en-US"], roles: [.standard, .standard, .audioDescription], defaultIndex: 0), 2)
        XCTAssertNil(MediaLanguageResolver.index(for: .language("zh-Hant"), languages: ["zh-Hans"], defaultIndex: nil, allowsOff: true))
    }
}
