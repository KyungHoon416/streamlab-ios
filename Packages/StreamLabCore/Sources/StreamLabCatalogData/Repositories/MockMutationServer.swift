import Foundation
import StreamLabDomain

/// Local mock transport, not a network backend. Optional disk state preserves receipts across relaunch.
public actor MockMutationServer: MutationTransport, MutationSnapshotSource {
    private struct Device: Codable, Hashable { let scope: MutationScope; let id: UUID }
    private struct Receipt: Codable { let mutation: DurableMutation; let revision: UInt64 }
    private struct State: Codable {
        var revisions: [MutationScope: UInt64] = [:]
        var records: [MutationScope: [String: Data]] = [:]
        var sequences: [Device: UInt64] = [:]
        var receipts: [UUID: Receipt] = [:]
        var myListVersions: [MutationScope: [String: UInt64]]? = nil
        var myListFloors: [MutationScope: UInt64]? = nil
        var revokedDevices: Set<UUID>? = nil // Optional to decode existing mock files.
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
        guard !(state.revokedDevices ?? []).contains(mutation.deviceID) else {
            throw MutationQueueError.inactive
        }
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
        if mutation.key == "my-list" {
            let oldData = state.records[mutation.scope]?["my-list"]
            let oldItems = oldData.flatMap { try? JSONDecoder().decode([CatalogTitle].self, from: $0) }
            let newItems = mutation.value.flatMap { try? JSONDecoder().decode([CatalogTitle].self, from: $0) }
            if (oldData == nil || oldItems != nil), (mutation.value == nil || newItems != nil) {
                var versions = updated.myListVersions ?? [:]
                var floors = updated.myListFloors ?? [:]
                if versions[mutation.scope] == nil { floors[mutation.scope] = current }
                var items = versions[mutation.scope] ?? [:]
                let oldIDs = Set((oldItems ?? []).map(\.id))
                let newIDs = Set((newItems ?? []).map(\.id))
                for id in oldIDs.symmetricDifference(newIDs) { items[id] = next }
                if let change = mutation.myListChange { items[change.title.id] = next }
                versions[mutation.scope] = items
                updated.myListVersions = versions
                updated.myListFloors = floors
            } else {
                // Legacy opaque test/data payloads have no trustworthy item history.
                updated.myListVersions?[mutation.scope] = nil
                updated.myListFloors?[mutation.scope] = nil
            }
        }
        updated.records[mutation.scope, default: [:]][mutation.key] = mutation.value
        updated.revisions[mutation.scope] = next
        updated.sequences[device] = mutation.sequence
        updated.receipts[mutation.id] = Receipt(mutation: mutation, revision: next)
        try persist(updated)
        state = updated
        return next
    }

    /// Local demo cleanup, not deletion of a production account on a remote server.
    /// Retain only revoked random device IDs so late sends cannot recreate erased data.
    public func forgetAccount(_ accountID: String, revoking devices: Set<UUID>) throws {
        var updated = state
        var revoked = updated.revokedDevices ?? []
        revoked.formUnion(devices)
        for device in updated.sequences.keys where device.scope.accountID == accountID {
            revoked.insert(device.id)
        }
        for receipt in updated.receipts.values where receipt.mutation.scope.accountID == accountID {
            revoked.insert(receipt.mutation.deviceID)
        }
        updated.revokedDevices = revoked
        updated.myListVersions = updated.myListVersions?.filter { $0.key.accountID != accountID }
        updated.myListFloors = updated.myListFloors?.filter { $0.key.accountID != accountID }
        updated.records = updated.records.filter { $0.key.accountID != accountID }
        updated.revisions = updated.revisions.filter { $0.key.accountID != accountID }
        updated.sequences = updated.sequences.filter { $0.key.scope.accountID != accountID }
        updated.receipts = updated.receipts.filter { $0.value.mutation.scope.accountID != accountID }
        try persist(updated)
        state = updated
    }

    private func persist(_ updated: State) throws {
        if let storageURL {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: storageURL, options: .atomic)
        }
    }

    public func snapshot(for scope: MutationScope) -> MutationSnapshot {
        MutationSnapshot(scope: scope, revision: state.revisions[scope, default: 0],
                         values: state.records[scope, default: [:]],
                         myListItemRevisions: state.myListVersions?[scope] ?? (state.revisions[scope, default: 0] == 0 ? [:] : nil),
                         myListRevisionFloor: state.myListFloors?[scope] ?? state.revisions[scope, default: 0])
    }

    public func values(for scope: MutationScope) -> [String: Data] { state.records[scope, default: [:]] }
    public func revision(for scope: MutationScope) -> UInt64 { state.revisions[scope, default: 0] }
}
