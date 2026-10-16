import Foundation
import StreamLabDomain

/// One atomic file contains BOTH the local projection and unacknowledged requests.
/// MainActor serializes file transactions in this process. Not a multi-process database.
@MainActor public final class DurableMutationStore {
    private struct Journal: Codable {
        var version = 1
        let scope: MutationScope
        let deviceID: UUID
        var nextSequence: UInt64 = 1
        var revision: UInt64 = 0
        var values: [String: Data] = [:]
        var pending: [DurableMutation] = []
    }
    private let url: URL
    private let scope: MutationScope
    private var journal: Journal
    private var active = true
    private var flushing = false

    public static func defaultDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
            .appendingPathComponent("StreamLab/Mutations", isDirectory: true)
    }

    public init(directory: URL, scope: MutationScope,
                seed: @autoclosure () throws -> [String: Data] = [:]) throws {
        self.scope = scope
        // Separate path components with URL-safe encoding, including empty IDs.
        func component(_ value: String) -> String {
            "s" + Data(value.utf8).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
        }
        url = directory.appendingPathComponent(component(scope.accountID), isDirectory: true)
            .appendingPathComponent(component(scope.profileID) + ".json")
        journal = Journal(scope: scope, deviceID: UUID())
        if FileManager.default.fileExists(atPath: url.path) {
            journal = try read()
        } else {
            let initial = try seed()
            for key in initial.keys.sorted() {
                Self.append(key: key, value: initial[key], to: &journal)
            }
            try persist(journal)
        }
    }

    public var values: [String: Data] { journal.values }
    public var pending: [DurableMutation] { journal.pending }

    public func refresh() throws {
        guard active else { throw MutationQueueError.inactive }
        journal = try read()
    }

    public func set(_ value: Data?, forKey key: String) throws {
        guard active else { throw MutationQueueError.inactive }
        var next = try read()
        guard next.nextSequence < UInt64.max,
              next.revision < UInt64.max - UInt64(next.pending.count) else {
            throw MutationQueueError.exhausted
        }
        Self.append(key: key, value: value, to: &next)
        try persist(next)
        journal = next // Publish only after the atomic replacement succeeds.
    }

    /// FIFO, single-flight. Failures/cancellation retain the exact request for retry.
    /// Conflict policy and scheduling/backoff are deliberately owned by the caller.
    public func flush(using transport: any MutationTransport) async throws {
        guard active else { throw MutationQueueError.inactive }
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        while active {
            try Task.checkCancellation()
            try refresh()
            guard let head = journal.pending.first else { return }
            let revision = try await transport.send(head)
            try Task.checkCancellation()
            guard active else { throw MutationQueueError.inactive }
            var next = try read()
            guard next.pending.first == head, head.baseRevision < UInt64.max,
                  revision == head.baseRevision + 1 else { throw MutationQueueError.invalidReceipt }
            next.pending.removeFirst()
            next.revision = revision
            try persist(next)
            journal = next
        }
    }

    /// Profile switch retains queued work; a late response cannot acknowledge it.
    public func invalidate() { active = false }

    /// Call on explicit logout for this scope; invalidate before deleting on disk.
    public func deleteLocalData() throws {
        active = false
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        journal = Journal(scope: scope, deviceID: UUID())
    }

    private static func append(key: String, value: Data?, to next: inout Journal) {
        next.pending.append(DurableMutation(id: UUID(), scope: scope, deviceID: next.deviceID,
            sequence: next.nextSequence, baseRevision: next.revision + UInt64(next.pending.count),
            key: key, value: value))
        next.nextSequence += 1
        next.values[key] = value
    }

    private func read() throws -> Journal {
        let decoded = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url))
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
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
    }
}
