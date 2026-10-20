import Foundation
import StreamLabDomain

@MainActor public final class PlaybackLanguageStore {
    public struct Preferences: Codable, Equatable, Sendable {
        public var subtitles: MediaLanguagePreference = .off
        public var audio: MediaLanguagePreference = .automatic
        public var lastSubtitleLanguage: String? = nil
        public var captionsWhenMuted: Bool? = nil // Legacy records default to enabled.
        public var audioRole: AudioRole? = nil // Missing in v1 records: keep legacy language-only matching.
        public init() {}

        public func mutedSubtitlePreference(deviceLanguage: String) -> MediaLanguagePreference {
            if case .language = subtitles { return subtitles }
            return .language(lastSubtitleLanguage ?? deviceLanguage)
        }
    }
    private let defaults: UserDefaults
    private let key: String
    private var active = true

    public init(profileID: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "streamlab.languages.v1." + Data(profileID.utf8).base64EncodedString()
    }

    public var preferences: Preferences {
        guard active, let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return value
    }

    public func setSubtitles(_ preference: MediaLanguagePreference) {
        var value = preferences
        // Preserve a legacy selected language before switching it off.
        if case .language(let language) = value.subtitles,
           let normalized = MediaLanguageResolver.normalized(language) {
            value.lastSubtitleLanguage = normalized
        }
        if case .language(let language) = preference,
           let normalized = MediaLanguageResolver.normalized(language) {
            value.lastSubtitleLanguage = normalized
        }
        value.subtitles = preference
        save(value)
    }

    public func setAudio(_ preference: MediaLanguagePreference, role: AudioRole? = nil) {
        guard preference != .off else { return }
        var value = preferences
        value.audio = preference
        value.audioRole = preference == .automatic ? nil : role
        save(value)
    }

    public func setCaptionsWhenMuted(_ enabled: Bool) {
        var value = preferences
        value.captionsWhenMuted = enabled
        save(value)
    }

    public func invalidate() { active = false }

    private func save(_ value: Preferences) {
        guard active else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
