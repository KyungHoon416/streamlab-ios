import Foundation

public struct MutationScope: Codable, Hashable, Sendable {
    public let accountID: String
    public let profileID: String
    public init(accountID: String, profileID: String) {
        self.accountID = accountID
        self.profileID = profileID
    }
}

/// Explicit user action, distinct from an ordinary checkpoint/tombstone.
public enum MutationIntent: String, Codable, Sendable { case restartPlayback }

/// An immutable retry envelope. Retries must reuse every field, including the ID.
public struct DurableMutation: Codable, Equatable, Sendable {
    public let id: UUID
    public let scope: MutationScope
    public let deviceID: UUID
    public let sequence: UInt64
    public let baseRevision: UInt64
    public let key: String
    public let value: Data?
    public let intent: MutationIntent?

    public init(id: UUID, scope: MutationScope, deviceID: UUID, sequence: UInt64,
                baseRevision: UInt64, key: String, value: Data?, intent: MutationIntent? = nil) {
        self.id = id
        self.scope = scope
        self.deviceID = deviceID
        self.sequence = sequence
        self.baseRevision = baseRevision
        self.key = key
        self.value = value
        self.intent = intent
    }
}

public enum MutationQueueError: Error, Equatable {
    case inactive, invalidJournal, exhausted, invalidReceipt
    case conflict(currentRevision: UInt64)
    case reusedID, outOfOrder
}

public protocol MutationTransport: Sendable {
    /// Return the committed revision; throw on conflict/offline/auth/rate limit.
    func send(_ mutation: DurableMutation) async throws -> UInt64
}

/// Revision and values are read atomically for exactly one account/profile.
public struct MutationSnapshot: Sendable {
    public let scope: MutationScope
    public let revision: UInt64
    public let values: [String: Data]
    public init(scope: MutationScope, revision: UInt64, values: [String: Data]) {
        self.scope = scope
        self.revision = revision
        self.values = values
    }
}

public protocol MutationSnapshotSource: Sendable {
    func snapshot(for scope: MutationScope) async throws -> MutationSnapshot
}
