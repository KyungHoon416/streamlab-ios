import Foundation
import StreamLabDomain

/// In-process server simulation. The actor is the transaction boundary; no wall clocks.
public actor MockProgressServer: ProgressServer {
    private var records: [ProgressIdentity: ProgressSnapshot] = [:]
    private var receipts: [UUID: (ProgressCommand, ProgressReply)] = [:]
    public init() {}

    public func fetch(_ identity: ProgressIdentity) -> ProgressSnapshot {
        records[identity] ?? ProgressSnapshot()
    }

    public func apply(_ command: ProgressCommand) throws -> ProgressReply {
        if let (original, reply) = receipts[command.id] {
            guard original == command else { throw ProgressSyncError.reusedCommandID }
            return reply
        }
        let position: Double
        switch command.mutation {
        case .checkpoint(let value):
            guard value.isFinite, value >= 0 else { throw ProgressSyncError.invalidPosition }
            position = value
        case .restart: position = 0
        }
        let current = fetch(command.identity)
        guard command.baseRevision == current.revision else {
            let reply = ProgressReply(accepted: false, snapshot: current)
            receipts[command.id] = (command, reply)
            return reply
        }
        guard current.revision < UInt64.max else { throw ProgressSyncError.revisionExhausted }
        let next = ProgressSnapshot(revision: current.revision + 1, position: position)
        records[command.identity] = next
        let reply = ProgressReply(accepted: true, snapshot: next)
        receipts[command.id] = (command, reply)
        return reply
    }
}
