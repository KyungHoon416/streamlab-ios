import Foundation

public enum MediaLanguagePreference: Codable, Equatable, Sendable {
    case automatic
    case off
    case language(String)
}

/// Stable language matching; transient AVFoundation option indices are never persisted.
public enum MediaLanguageResolver {
    public static func normalized(_ tag: String?) -> String? {
        guard let tag else { return nil }
        let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-").lowercased()
        guard value.split(separator: "-").first != nil, value != "und" else { return nil }
        return value
    }

    public static func index(for preference: MediaLanguagePreference, languages: [String?],
                             defaultIndex: Int?, allowsOff: Bool) -> Int? {
        if preference == .off && allowsOff { return nil }
        if case .language(let tag) = preference, let wanted = normalized(tag) {
            let tags = languages.map { normalized($0) }
            if let exact = tags.firstIndex(where: { $0 == wanted }) { return exact }
            // Prefer a generic language track; do not substitute a different explicit script/region.
            let primary = String(wanted.split(separator: "-")[0])
            if let generic = tags.firstIndex(where: { $0 == primary }) { return generic }
            if !wanted.contains("-"), let related = tags.firstIndex(where: {
                $0?.split(separator: "-").first.map(String.init) == primary
            }) { return related }
        }
        if let defaultIndex, languages.indices.contains(defaultIndex) { return defaultIndex }
        return allowsOff ? nil : languages.indices.first
    }
}

/// Semantic role, independent of localized display names and playlist ordering.
public enum AudioRole: String, Codable, Equatable, Sendable {
    case standard
    case audioDescription
}

public enum AudioPreferenceResolver {
    public static func index(for preference: MediaLanguagePreference, role: AudioRole?,
                             languages: [String?], roles: [AudioRole], defaultIndex: Int?) -> Int? {
        let fallback = MediaLanguageResolver.index(for: preference, languages: languages,
                                                   defaultIndex: defaultIndex, allowsOff: false)
        guard case .language = preference, let role,
              let languageIndex = MediaLanguageResolver.index(for: preference, languages: languages,
                                                              defaultIndex: nil, allowsOff: true),
              let language = MediaLanguageResolver.normalized(languages[languageIndex]) else { return fallback }
        let candidates = languages.indices.filter {
            MediaLanguageResolver.normalized(languages[$0]) == language
                && roles.indices.contains($0) && roles[$0] == role
        }
        if let defaultIndex, candidates.contains(defaultIndex) { return defaultIndex }
        // Missing roles fall back within the matching language, without rewriting the preference.
        return candidates.first ?? languageIndex
    }
}
