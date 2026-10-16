import Foundation
import StreamLabDomain

/// Local mock transport, not a network backend. Optional disk state preserves receipts across relaunch.
public actor MockMutationServer: MutationTransport {
    private struct Device: Codable, Hashable { let scope: MutationScope; let id: UUID }
    private struct Receipt: Codable { let mutation: DurableMutation; let revision: UInt64 }
    private struct State: Codable {
        var revisions: [MutationScope: UInt64] = [:]
        var records: [MutationScope: [String: Data]] = [:]
        var sequences: [Device: UInt64] = [:]
        var receipts: [UUID: Receipt] = [:]
    }
    private var state = State()
    private let storageURL: URL?
    public init() { storageURL = nil }
    public init(storageURL: URL) throws {
        self.storageURL = storageURL
        if FileManager.default.fileExists(atPath: storageURL.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: storageURL))
        }
    }

    public func send(_ mutation: DurableMutation) throws -> UInt64 {
        if let receipt = state.receipts[mutation.id] {
            guard receipt.mutation == mutation else { throw MutationQueueError.reusedID }
            return receipt.revision
        }
        let current = state.revisions[mutation.scope, default: 0]
        guard mutation.baseRevision == current else {
            throw MutationQueueError.conflict(currentRevision: current)
        }
        let device = Device(scope: mutation.scope, id: mutation.deviceID)
        guard mutation.sequence > state.sequences[device, default: 0] else {
            throw MutationQueueError.outOfOrder
        }
        guard current < UInt64.max else { throw MutationQueueError.exhausted }
        let next = current + 1
        var updated = state
        updated.records[mutation.scope, default: [:]][mutation.key] = mutation.value
        updated.revisions[mutation.scope] = next
        updated.sequences[device] = mutation.sequence
        updated.receipts[mutation.id] = Receipt(mutation: mutation, revision: next)
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: storageURL, options: .atomic)
        }
        state = updated
        return next
    }

    public func values(for scope: MutationScope) -> [String: Data] { state.records[scope, default: [:]] }
    public func revision(for scope: MutationScope) -> UInt64 { state.revisions[scope, default: 0] }
}
