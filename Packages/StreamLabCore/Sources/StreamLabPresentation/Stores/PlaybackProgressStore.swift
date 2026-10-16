import Foundation
import StreamLabDomain

/// Main-actor persistence scoped permanently to one profile.
@MainActor public final class PlaybackProgressStore {
    private struct Record: Codable {
        let position: Double
        let duration: Double
        var updatedAt: Date? = nil
        // Optional for backward-compatible decoding of existing v1 records.
        var profileID: String? = nil
        var titleID: String? = nil
        var sourceID: String? = nil

        func matches(profile: String, title: String, source: String) -> Bool {
            (profileID == nil || profileID == profile) &&
            (titleID == nil || titleID == title) &&
            (sourceID == nil || sourceID == source)
        }
    }
    private let profileID: String
    private let defaults: UserDefaults
    private let durable: Bool
    private var queue: DurableMutationStore?
    private var active = true
    public private(set) var persistenceError: String?
    public var onMutation: (@MainActor () -> Void)?
    public var pendingMutations: [DurableMutation] { queue?.pending ?? [] }

    /// The legacy mode remains available for existing callers/tests. App sessions opt in
    /// to the durable journal, with no fallback to a second writer if the journal fails.
    public init(profileID: String, defaults: UserDefaults = .standard,
                durable: Bool = false, directory: URL? = nil, accountID: String = "local-demo") {
        self.profileID = profileID
        self.defaults = defaults
        self.durable = durable
        if durable {
            do {
                let root: URL
                if let directory { root = directory }
                else {
                    root = try DurableMutationStore.defaultDirectory()
                        .appendingPathComponent("Progress", isDirectory: true)
                }
                queue = try DurableMutationStore(directory: root,
                    scope: MutationScope(accountID: accountID, profileID: profileID),
                    seed: accountID == "local-demo" ? legacyRecords() : [:])
            } catch {
                persistenceError = "시청 기록을 불러오지 못했습니다. 기존 데이터는 유지됩니다."
            }
        }
    }

    private var prefix: String {
        "streamlab.progress.v1." + Data(profileID.utf8).base64EncodedString() + "."
    }

    // Legacy keys have no account identity; only the original demo account may import them.
    private func legacyRecords() -> [String: Data] {
        var result: [String: Data] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            guard let data = value as? Data,
                  let identity = identity(for: key),
                  let record = try? JSONDecoder().decode(Record.self, from: data),
                  record.matches(profile: profileID, title: identity.title, source: identity.source),
                  record.position.isFinite, record.duration.isFinite, record.duration > 0,
                  record.position >= 1,
                  record.position < record.duration - min(5, record.duration * 0.05) else { continue }
            result[key] = data
        }
        return result
    }

    private func identity(for key: String) -> (title: String, source: String)? {
        guard key.hasPrefix(prefix) else { return nil }
        let parts = String(key.dropFirst(prefix.count)).components(separatedBy: ".")
        guard parts.count == 2,
              let titleData = Data(base64Encoded: parts[0]), let title = String(data: titleData, encoding: .utf8),
              let sourceData = Data(base64Encoded: parts[1]), let source = String(data: sourceData, encoding: .utf8) else { return nil }
        return (title, source)
    }

    private var records: [String: Data] {
        guard active else { return [:] }
        if durable { return queue?.values ?? [:] }
        return defaults.dictionaryRepresentation().reduce(into: [:]) { result, entry in
            if entry.key.hasPrefix(prefix), let data = entry.value as? Data { result[entry.key] = data }
        }
    }

    public func flush(using transport: any MutationTransport) async throws {
        guard active, let queue else { throw MutationQueueError.inactive }
        try await queue.flush(using: transport)
    }

    public func invalidate() {
        active = false
        onMutation = nil
        queue?.invalidate()
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
        let entries = records.compactMap { key, data -> Entry? in
            guard key.hasPrefix(prefix),
                  let record = try? JSONDecoder().decode(Record.self, from: data),
                  record.duration.isFinite, record.duration > 0,
                  record.position.isFinite, record.position >= 1,
                  record.position < record.duration - min(5, record.duration * 0.05) else { return nil }
            guard let identity = identity(for: key) else { return nil }
            let title = identity.title
            let source = identity.source
            guard record.matches(profile: profileID, title: title, source: source) else { return nil }
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
              let data = records[key(titleID: titleID, sourceID: sourceID)],
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.matches(profile: profileID, title: titleID, source: sourceID),
              record.duration.isFinite, abs(record.duration - duration) <= max(1, duration * 0.01),
              record.position.isFinite, record.position >= 1,
              record.position < duration - min(5, duration * 0.05) else { return nil }
        return record.position
    }

    public func save(titleID: String, sourceID: String, position: Double, duration: Double) {
        guard active, position.isFinite, duration.isFinite, duration > 0, position >= 0 else { return }
        let key = key(titleID: titleID, sourceID: sourceID)
        do {
            let data: Data?
            if position >= 1, position < duration - min(5, duration * 0.05) {
                data = try JSONEncoder().encode(Record(position: position, duration: duration,
                    updatedAt: Date(), profileID: profileID, titleID: titleID, sourceID: sourceID))
            } else {
                // Completion/restart is a queued tombstone, not just a local deletion.
                data = nil
            }
            if durable {
                guard let queue else { throw MutationQueueError.inactive }
                try queue.set(data, forKey: key)
            } else if let data {
                defaults.set(data, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            persistenceError = nil
            onMutation?()
        } catch {
            persistenceError = "시청 기록을 저장하지 못했습니다. 다시 시도해 주세요."
        }
    }
}
