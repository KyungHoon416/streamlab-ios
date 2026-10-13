import Foundation

/// Main-actor persistence scoped permanently to one profile.
@MainActor public final class PlaybackProgressStore {
    private struct Record: Codable {
        let position: Double
        let duration: Double
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
        guard let data = try? JSONEncoder().encode(Record(position: position, duration: duration)) else { return }
        defaults.set(data, forKey: key)
    }
}
