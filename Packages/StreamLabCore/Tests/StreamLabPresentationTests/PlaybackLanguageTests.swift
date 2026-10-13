import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation

@MainActor struct PlaybackLanguageTests {
    @Test func persistsAcrossInstancesAndIsolatesProfiles() throws {
        let name = "language-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let a = PlaybackLanguageStore(profileID: "adult-a", defaults: defaults)
        a.setSubtitles(.language("ko"))
        a.setAudio(.language("en-US"))
        let reopened = PlaybackLanguageStore(profileID: "adult-a", defaults: defaults)
        #expect(reopened.preferences.subtitles == .language("ko"))
        #expect(reopened.preferences.audio == .language("en-US"))
        let kids = PlaybackLanguageStore(profileID: "kids", defaults: defaults)
        #expect(kids.preferences == .init())
        reopened.setSubtitles(.off)
        #expect(a.preferences.subtitles == .off)
        #expect(a.preferences.audio == .language("en-US"))
        reopened.setAudio(.off)
        #expect(a.preferences.audio == .language("en-US"))
    }

    @Test func matchesLanguagesIndependentOfOptionOrder() {
        #expect(MediaLanguageResolver.index(for: .language("en_US"), languages: ["ko", "en-US"], defaultIndex: 0, allowsOff: true) == 1)
        #expect(MediaLanguageResolver.index(for: .language("ko-KR"), languages: ["en", "ko"], defaultIndex: 0, allowsOff: true) == 1)
        #expect(MediaLanguageResolver.index(for: .language("en"), languages: ["en-GB", "ko"], defaultIndex: 1, allowsOff: true) == 0)
        #expect(MediaLanguageResolver.index(for: .language("zh-Hant"), languages: ["zh-Hans"], defaultIndex: nil, allowsOff: true) == nil)
    }

    @Test func fallsBackWithoutOverwritingPreference() throws {
        let name = "language-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        store.setAudio(.language("ko"))
        #expect(MediaLanguageResolver.index(for: store.preferences.audio, languages: ["en"], defaultIndex: 0, allowsOff: false) == 0)
        #expect(store.preferences.audio == .language("ko"))
        #expect(MediaLanguageResolver.index(for: store.preferences.audio, languages: ["en", "ko"], defaultIndex: 0, allowsOff: false) == 1)
        #expect(MediaLanguageResolver.index(for: .off, languages: ["ko"], defaultIndex: 0, allowsOff: true) == nil)
        #expect(MediaLanguageResolver.index(for: .off, languages: ["ko"], defaultIndex: 0, allowsOff: false) == 0)
        #expect(MediaLanguageResolver.index(for: .automatic, languages: [], defaultIndex: 0, allowsOff: false) == nil)
        #expect(MediaLanguageResolver.normalized("und") == nil)
        #expect(MediaLanguageResolver.normalized(nil) == nil)
    }
}
