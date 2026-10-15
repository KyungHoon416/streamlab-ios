import Foundation

public struct ProgressIdentity: Hashable, Sendable {
    public let profileID: String
    public let titleID: String
    public let sourceID: String
    public init(profileID: String, titleID: String, sourceID: String) {
        self.profileID = profileID; self.titleID = titleID; self.sourceID = sourceID
    }
}

public struct ProgressSnapshot: Equatable, Sendable {
    public let revision: UInt64
    public let position: Double
    public init(revision: UInt64 = 0, position: Double = 0) {
        self.revision = revision; self.position = position
    }
}

public enum ProgressMutation: Equatable, Sendable {
    case checkpoint(Double)
    case restart
}

public struct ProgressCommand: Equatable, Sendable {
    public let id: UUID
    public let identity: ProgressIdentity
    public let deviceID: String
    public let baseRevision: UInt64
    public let mutation: ProgressMutation
    public init(id: UUID = UUID(), identity: ProgressIdentity, deviceID: String,
                baseRevision: UInt64, mutation: ProgressMutation) {
        self.id = id; self.identity = identity; self.deviceID = deviceID
        self.baseRevision = baseRevision; self.mutation = mutation
    }
}

public struct ProgressReply: Equatable, Sendable {
    public let accepted: Bool
    public let snapshot: ProgressSnapshot
    public init(accepted: Bool, snapshot: ProgressSnapshot) {
        self.accepted = accepted; self.snapshot = snapshot
    }
}

public enum ProgressSyncError: Error, Equatable, Sendable {
    case invalidPosition, reusedCommandID, revisionExhausted
}

public protocol ProgressServer: Sendable {
    func fetch(_ identity: ProgressIdentity) async -> ProgressSnapshot
    func apply(_ command: ProgressCommand) async throws -> ProgressReply
}
