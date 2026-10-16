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

    @Test func migratesLegacyAndPersistsAudioRolePerProfile() throws {
        struct Legacy: Encodable {
            let subtitles: MediaLanguagePreference
            let audio: MediaLanguagePreference
        }
        let name = "audio-role-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let key = "streamlab.languages.v1." + Data("a".utf8).base64EncodedString()
        defaults.set(try JSONEncoder().encode(Legacy(subtitles: .language("ko"), audio: .language("en-US"))), forKey: key)
        let store = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        #expect(store.preferences.audio == .language("en-US"))
        #expect(store.preferences.subtitles == .language("ko"))
        #expect(store.preferences.audioRole == nil)
        store.setAudio(.language("en-US"), role: .audioDescription)
        let reopened = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        #expect(reopened.preferences.audioRole == .audioDescription)
        #expect(reopened.preferences.subtitles == .language("ko"))
        #expect(PlaybackLanguageStore(profileID: "b", defaults: defaults).preferences.audioRole == nil)
        store.setAudio(.off, role: .standard)
        #expect(store.preferences.audioRole == .audioDescription)
        store.setAudio(.language("en-US"), role: .standard)
        #expect(reopened.preferences.audioRole == .standard)
        store.setAudio(.automatic)
        #expect(reopened.preferences.audioRole == nil)
        #expect(reopened.preferences.audio == .automatic)
    }

    @Test func audioRolesSurviveReorderingAndRespectLanguage() {
        #expect(AudioPreferenceResolver.index(for: .language("en-US"), role: .audioDescription,
            languages: ["en-US", "en-US"], roles: [.standard, .audioDescription], defaultIndex: 0) == 1)
        #expect(AudioPreferenceResolver.index(for: .language("en_US"), role: .audioDescription,
            languages: ["en-US", "en-US"], roles: [.audioDescription, .standard], defaultIndex: 1) == 0)
        #expect(AudioPreferenceResolver.index(for: .language("en-US"), role: .standard,
            languages: ["en-US", "en-US"], roles: [.audioDescription, .standard], defaultIndex: 0) == 1)
        #expect(AudioPreferenceResolver.index(for: .language("en-US"), role: .audioDescription,
            languages: ["ko", "en-US"], roles: [.audioDescription, .standard], defaultIndex: 0) == 1)
        #expect(AudioPreferenceResolver.index(for: .automatic, role: nil,
            languages: ["en-US", "en-US"], roles: [.audioDescription, .standard], defaultIndex: 1) == 1)
        #expect(AudioPreferenceResolver.index(for: .language("en"), role: .audioDescription,
            languages: [], roles: [], defaultIndex: 0) == nil)
    }

    @Test func regionalDVSPreferenceFallsBackToGenericEnglishAndReturnsToDVS() {
        // The real masters advertise en-US for the DVS sample and en for standard audio.
        #expect(AudioPreferenceResolver.index(for: .language("en-US"), role: .audioDescription,
            languages: ["fr", "en"], roles: [.standard, .standard], defaultIndex: 0) == 1)
        #expect(AudioPreferenceResolver.index(for: .language("en-US"), role: .audioDescription,
            languages: ["en-US", "en-US"], roles: [.standard, .audioDescription], defaultIndex: 0) == 1)
    }

    @Test func missingRoleDoesNotEraseSavedSelection() throws {
        let name = "audio-role-fallback-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackLanguageStore(profileID: "a", defaults: defaults)
        store.setAudio(.language("en-US"), role: .audioDescription)
        let wanted = store.preferences
        #expect(AudioPreferenceResolver.index(for: wanted.audio, role: wanted.audioRole,
            languages: ["en-US"], roles: [.standard], defaultIndex: 0) == 0)
        #expect(store.preferences == wanted)
        #expect(AudioPreferenceResolver.index(for: wanted.audio, role: wanted.audioRole,
            languages: ["ko"], roles: [.audioDescription], defaultIndex: 0) == 0)
        #expect(store.preferences == wanted)
        #expect(AudioPreferenceResolver.index(for: wanted.audio, role: wanted.audioRole,
            languages: ["en-US", "en-US"], roles: [.standard, .audioDescription], defaultIndex: 0) == 1)
    }
}
