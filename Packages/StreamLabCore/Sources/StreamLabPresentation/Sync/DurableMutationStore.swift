import Foundation
import StreamLabDomain

/// SQLite commits the local projection, metadata and outbox in one transaction.
/// MainActor serializes application writes. Legacy JSON is migrated exactly once.
@MainActor public final class DurableMutationStore {
    private struct Journal: Codable {
        var version = 1
        let scope: MutationScope
        let deviceID: UUID
        var nextSequence: UInt64 = 1
        var revision: UInt64 = 0
        var values: [String: Data] = [:]
        var pending: [DurableMutation] = []
        var acknowledgedMyListRevisions: [String: UInt64]? = nil
    }
    private final class WeakStore {
        weak var value: DurableMutationStore?
        init(_ value: DurableMutationStore) { self.value = value }
    }
    private static var instances: [WeakStore] = []
    private let directory: URL
    private let database: SQLiteMutationDatabase
    private let legacyURL: URL
    private let scope: MutationScope
    private var journal: Journal
    private var active = true
    private var flushing = false
    public private(set) var reconciliationCount = 0

    private static var cachedDefaultDirectory: URL?

    public static func defaultDirectory() throws -> URL {
        if let cachedDefaultDirectory { return cachedDefaultDirectory }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("StreamLab/Mutations", isDirectory: true)
        cachedDefaultDirectory = directory
        return directory
    }

    public init(directory: URL, scope: MutationScope,
                seed: @autoclosure () throws -> [String: Data] = [:]) throws {
        self.scope = scope
        self.directory = directory.standardizedFileURL
        let account = Self.accountDirectory(directory: directory, accountID: scope.accountID)
        database = SQLiteMutationDatabase(url: account.appendingPathComponent(Self.component(scope.profileID) + ".sqlite"))
        legacyURL = account.appendingPathComponent(Self.component(scope.profileID) + ".json")
        journal = Journal(scope: scope, deviceID: UUID())
        if let snapshot = try database.read() {
            journal = try decode(snapshot)
        } else if FileManager.default.fileExists(atPath: legacyURL.path) {
            let legacy = try validated(JSONDecoder().decode(Journal.self, from: Data(contentsOf: legacyURL)))
            try persist(legacy)
            journal = try read() // Read back before retiring the migration source.
        } else {
            let initial = try seed()
            for key in initial.keys.sorted() {
                Self.append(key: key, value: initial[key], to: &journal)
            }
            try persist(journal)
        }
        // A crash after COMMIT and before this removal resumes from SQLite, never old JSON.
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            try FileManager.default.removeItem(at: legacyURL)
        }
        Self.instances.removeAll { $0.value == nil }
        Self.instances.append(WeakStore(self))
    }

    private static func component(_ value: String) -> String {
        "s" + Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }

    public static func accountDirectory(directory: URL, accountID: String) -> URL {
        directory.appendingPathComponent(component(accountID), isDirectory: true)
    }

    /// Revoke all live stores for this account before deleting any files. Includes
    /// stores retained by old tasks after a profile switch; other accounts stay active.
    public static func revokeAccount(_ accountID: String, directories: [URL]) -> Set<UUID> {
        let roots = Set(directories.map { $0.standardizedFileURL.path })
        var devices = Set<UUID>()
        instances.removeAll { $0.value == nil }
        for entry in instances {
            guard let store = entry.value, store.scope.accountID == accountID,
                  roots.contains(store.directory.path) else { continue }
            devices.insert(store.journal.deviceID)
            store.active = false
            store.journal = Journal(scope: store.scope, deviceID: store.journal.deviceID)
        }
        return devices
    }

    public var values: [String: Data] { journal.values }
    public var pending: [DurableMutation] { journal.pending }
    public var committedRevision: UInt64 { journal.revision }

    public func refresh() throws {
        guard active else { throw MutationQueueError.inactive }
        journal = try read()
    }

    public func set(_ value: Data?, forKey key: String, intent: MutationIntent? = nil,
                    searchDeletion: SearchDeletion? = nil, myListChange: MyListChange? = nil) throws {
        guard active else { throw MutationQueueError.inactive }
        var next = try read()
        guard next.nextSequence < UInt64.max,
              next.revision < UInt64.max - UInt64(next.pending.count) else {
            throw MutationQueueError.exhausted
        }
        Self.append(key: key, value: value, intent: intent, searchDeletion: searchDeletion, myListChange: myListChange, to: &next)
        try persist(next)
        journal = next // Publish only after SQLite COMMIT succeeds.
    }

    /// FIFO, single-flight. Failures/cancellation retain the exact request for retry.
    /// Conflict policy and scheduling/backoff are deliberately owned by the caller.
    public func flush(using transport: any MutationTransport,
                      serverWins snapshots: (any MutationSnapshotSource)? = nil,
                      preservePlaybackRestarts: Bool = false,
                      preserveSearchDeletions: Bool = false, mergeMyListItems: Bool = false) async throws {
        guard active else { throw MutationQueueError.inactive }
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        var conflicts = 0
        while active {
            try Task.checkCancellation()
            try refresh()
            guard let head = journal.pending.first else {
                if let snapshots { try await adoptServerSnapshot(from: snapshots) }
                return
            }
            let attemptedSequence = journal.nextSequence
            let revision: UInt64
            do {
                revision = try await transport.send(head)
            } catch MutationQueueError.conflict(let currentRevision) {
                guard let snapshots else { throw MutationQueueError.conflict(currentRevision: currentRevision) }
                guard try read().nextSequence == attemptedSequence else {
                    throw MutationQueueError.invalidReceipt
                }
                guard conflicts < 3 else { throw MutationQueueError.conflict(currentRevision: currentRevision) }
                try await adoptServerSnapshot(from: snapshots, minimumRevision: currentRevision,
                                              preserveRestarts: preservePlaybackRestarts, preserveSearchDeletions: preserveSearchDeletions,
                                              mergeMyListItems: mergeMyListItems)
                conflicts += 1
                if preservePlaybackRestarts || preserveSearchDeletions || mergeMyListItems, !journal.pending.isEmpty { continue }
                return
            }
            try Task.checkCancellation()
            guard active else { throw MutationQueueError.inactive }
            var next = try read()
            guard next.pending.first == head, head.baseRevision < UInt64.max,
                  revision == head.baseRevision + 1 else { throw MutationQueueError.invalidReceipt }
            next.pending.removeFirst()
            next.revision = revision
            if head.key == "my-list", let change = head.myListChange {
                var acknowledged = next.acknowledgedMyListRevisions ?? [:]
                acknowledged[change.title.id] = revision
                next.acknowledgedMyListRevisions = acknowledged
            }
            try persist(next)
            journal = next
        }
    }

    /// Opt-in reconciliation preserving explicit restart or search deletion intents.
    /// New local edits made during the fetch must survive; caller can retry reconciliation.
    private func adoptServerSnapshot(from source: any MutationSnapshotSource,
                                     minimumRevision: UInt64 = 0, preserveRestarts: Bool = false,
                                     preserveSearchDeletions: Bool = false, mergeMyListItems: Bool = false) async throws {
        try Task.checkCancellation()
        guard active else { throw MutationQueueError.inactive }
        let before = try read()
        let snapshot = try await source.snapshot(for: scope)
        try Task.checkCancellation()
        guard active else { throw MutationQueueError.inactive }
        var next = try read()
        guard snapshot.scope == scope, snapshot.revision >= minimumRevision,
              snapshot.revision >= next.revision,
              next.nextSequence == before.nextSequence, next.pending == before.pending,
              next.revision == before.revision else { throw MutationQueueError.invalidReceipt }
        // Preserve only the last explicit restart per key and its subsequent local events.
        // A conflict definitively rejects the old head; new envelopes receive new IDs/sequences.
        var restartOffsets: [String: Int] = [:]
        if preserveRestarts {
            for (index, item) in next.pending.enumerated() where item.intent == .restartPlayback {
                restartOffsets[item.key] = index
            }
        }
        let retained = next.pending.enumerated().compactMap { index, item -> DurableMutation? in
            if mergeMyListItems, item.key == "my-list", let change = item.myListChange,
               let versions = snapshot.myListItemRevisions,
               change.observedRevision <= before.revision,
               (versions[change.title.id] ?? snapshot.myListRevisionFloor) <= max(change.observedRevision, before.acknowledgedMyListRevisions?[change.title.id] ?? 0) {
                return item
            }
            if preserveSearchDeletions, item.key == "recent-searches", item.searchDeletion != nil { return item }
            guard let start = restartOffsets[item.key], index >= start else { return nil }
            return item
        }
        guard UInt64(retained.count) < UInt64.max - next.nextSequence,
              snapshot.revision <= UInt64.max - UInt64(retained.count) else {
            throw MutationQueueError.exhausted
        }
        next.values = snapshot.values
        next.revision = snapshot.revision
        next.pending = []
        for item in retained {
            if mergeMyListItems, let change = item.myListChange, item.key == "my-list" {
                var titles = try next.values[item.key].map { try JSONDecoder().decode([CatalogTitle].self, from: $0) } ?? []
                titles.removeAll { $0.id == change.title.id }
                if change.isSaved { titles.insert(change.title, at: 0) }
                let value = try JSONEncoder().encode(titles)
                let rebased = MyListChange(title: change.title, isSaved: change.isSaved,
                                           observedRevision: snapshot.revision)
                Self.append(key: item.key, value: value, myListChange: rebased, to: &next)
            } else if preserveSearchDeletions, let deletion = item.searchDeletion, item.key == "recent-searches" {
                let updated: [String]
                switch deletion {
                case .all: updated = []
                case .term(let identity):
                    let current = try next.values[item.key].map { try JSONDecoder().decode([String].self, from: $0) } ?? []
                    updated = current.filter { Self.searchIdentity($0) != Self.searchIdentity(identity) }
                }
                let value: Data?
                if updated.isEmpty { value = nil }
                else { value = try JSONEncoder().encode(updated) }
                Self.append(key: item.key, value: value, searchDeletion: deletion, to: &next)
            } else {
                Self.append(key: item.key, value: item.value, intent: item.intent, to: &next)
            }
        }
        try persist(next) // Projection + rejection of stale batch commit together.
        journal = next
        if retained.isEmpty, before.values != snapshot.values || before.revision != snapshot.revision {
            reconciliationCount += 1
        }
    }

    /// Profile switch retains queued work; a late response cannot acknowledge it.
    public func invalidate() { active = false }

    /// Call on explicit logout for this scope; invalidate before deleting on disk.
    public func deleteLocalData() throws {
        active = false
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            try FileManager.default.removeItem(at: legacyURL)
        }
        try database.delete()
        journal = Journal(scope: scope, deviceID: UUID())
    }

    private static func append(key: String, value: Data?, intent: MutationIntent? = nil,
                               searchDeletion: SearchDeletion? = nil, myListChange: MyListChange? = nil, to next: inout Journal) {
        next.pending.append(DurableMutation(id: UUID(), scope: next.scope, deviceID: next.deviceID,
            sequence: next.nextSequence, baseRevision: next.revision + UInt64(next.pending.count),
            key: key, value: value, intent: intent, searchDeletion: searchDeletion, myListChange: myListChange))
        next.nextSequence += 1
        next.values[key] = value
    }

    private static func searchIdentity(_ value: String) -> String {
        String(value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .precomposedStringWithCanonicalMapping.prefix(100)).lowercased()
    }

    private func read() throws -> Journal {
        guard let snapshot = try database.read() else { throw MutationQueueError.invalidJournal }
        return try decode(snapshot)
    }

    private func decode(_ snapshot: SQLiteMutationDatabase.Snapshot) throws -> Journal {
        var decoded = try JSONDecoder().decode(Journal.self, from: snapshot.metadata)
        guard decoded.values.isEmpty, decoded.pending.isEmpty else { throw MutationQueueError.invalidJournal }
        decoded.values = snapshot.values
        decoded.pending = try snapshot.outbox.map { try JSONDecoder().decode(DurableMutation.self, from: $0) }
        return try validated(decoded)
    }

    private func validated(_ decoded: Journal) throws -> Journal {
        guard decoded.version == 1, decoded.scope == scope, decoded.nextSequence > 0,
              decoded.revision <= UInt64.max - UInt64(decoded.pending.count) else {
            throw MutationQueueError.invalidJournal
        }
        var ids = Set<UUID>()
        var previous: UInt64 = 0
        for (offset, item) in decoded.pending.enumerated() {
            guard item.scope == scope, item.deviceID == decoded.deviceID,
                  item.sequence > previous, item.sequence < decoded.nextSequence,
                  item.baseRevision == decoded.revision + UInt64(offset),
                  ids.insert(item.id).inserted else { throw MutationQueueError.invalidJournal }
            previous = item.sequence
        }
        return decoded
    }

    private func persist(_ next: Journal) throws {
        var metadata = next
        metadata.values = [:]
        metadata.pending = []
        try database.write(.init(metadata: JSONEncoder().encode(metadata), values: next.values,
                                 outbox: next.pending.map { try JSONEncoder().encode($0) }))
    }
}
