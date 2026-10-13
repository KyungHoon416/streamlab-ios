import Foundation

/// Main-actor persistence scoped permanently to one profile.
@MainActor public final class PlaybackProgressStore {
    private struct Record: Codable {
        let position: Double
        let duration: Double
        var updatedAt: Date? = nil
    }
    private let profileID: String
    private let defaults: UserDefaults

    public init(profileID: String, defaults: UserDefaults = .standard) {
        self.profileID = profileID
        self.defaults = defaults
    }

    private func key(titleID: String, sourceID: String) -> String {
        // Encode each component independently to avoid separator collisions.
        let parts = [profileID, titleID, sourceID].map { Data($0.utf8).base64EncodedString() }
        return "streamlab.progress.v1." + parts.joined(separator: ".")
    }

    public struct Entry: Sendable {
        public let titleID: String
        public let sourceID: String
        public let position: Double
        public let duration: Double
        public let updatedAt: Date
    }

    /// One latest playable source per title, never reads another profile's prefix.
    public func recent(limit: Int = 20) -> [Entry] {
        let prefix = "streamlab.progress.v1." + Data(profileID.utf8).base64EncodedString() + "."
        let entries = defaults.dictionaryRepresentation().compactMap { key, value -> Entry? in
            guard key.hasPrefix(prefix), let data = value as? Data,
                  let record = try? JSONDecoder().decode(Record.self, from: data),
                  record.duration.isFinite, record.duration > 0,
                  record.position.isFinite, record.position >= 1,
                  record.position < record.duration - min(5, record.duration * 0.05) else { return nil }
            let parts = String(key.dropFirst(prefix.count)).components(separatedBy: ".")
            guard parts.count == 2,
                  let titleData = Data(base64Encoded: parts[0]), let title = String(data: titleData, encoding: .utf8),
                  let sourceData = Data(base64Encoded: parts[1]), let source = String(data: sourceData, encoding: .utf8) else { return nil }
            return Entry(titleID: title, sourceID: source, position: record.position,
                         duration: record.duration, updatedAt: record.updatedAt ?? .distantPast)
        }.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return ($0.titleID, $0.sourceID) < ($1.titleID, $1.sourceID)
        }
        var seen = Set<String>()
        return Array(entries.filter { seen.insert($0.titleID).inserted }.prefix(max(0, limit)))
    }

    public func position(titleID: String, sourceID: String, duration: Double) -> Double? {
        guard duration.isFinite, duration > 0,
              let data = defaults.data(forKey: key(titleID: titleID, sourceID: sourceID)),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.duration.isFinite, abs(record.duration - duration) <= max(1, duration * 0.01),
              record.position.isFinite, record.position >= 1,
              record.position < duration - min(5, duration * 0.05) else { return nil }
        return record.position
    }

    public func save(titleID: String, sourceID: String, position: Double, duration: Double) {
        guard position.isFinite, duration.isFinite, duration > 0, position >= 0 else { return }
        let key = key(titleID: titleID, sourceID: sourceID)
        guard position >= 1, position < duration - min(5, duration * 0.05) else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(Record(position: position, duration: duration, updatedAt: Date())) else { return }
        defaults.set(data, forKey: key)
    }
}
