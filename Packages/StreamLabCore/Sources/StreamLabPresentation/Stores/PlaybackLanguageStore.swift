import Foundation
import StreamLabDomain

@MainActor public final class PlaybackLanguageStore {
    public struct Preferences: Codable, Equatable, Sendable {
        public var subtitles: MediaLanguagePreference = .off
        public var audio: MediaLanguagePreference = .automatic
        public init() {}
    }
    private let defaults: UserDefaults
    private let key: String

    public init(profileID: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "streamlab.languages.v1." + Data(profileID.utf8).base64EncodedString()
    }

    public var preferences: Preferences {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return value
    }

    public func setSubtitles(_ preference: MediaLanguagePreference) {
        var value = preferences
        value.subtitles = preference
        save(value)
    }

    public func setAudio(_ preference: MediaLanguagePreference) {
        guard preference != .off else { return }
        var value = preferences
        value.audio = preference
        save(value)
    }

    private func save(_ value: Preferences) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
