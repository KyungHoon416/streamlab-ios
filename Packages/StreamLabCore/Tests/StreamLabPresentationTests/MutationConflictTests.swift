import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 server wins reconciliation")
@MainActor struct MutationConflictTests {
    let scope = MutationScope(accountID: "account", profileID: "adult-a")
    func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    @Test func concurrentDevicesConvergeAndNewIntentCanCommit() async throws {
        let aRoot = root(), bRoot = root()
        defer { try? FileManager.default.removeItem(at: aRoot); try? FileManager.default.removeItem(at: bRoot) }
        let a = try DurableMutationStore(directory: aRoot, scope: scope)
        let b = try DurableMutationStore(directory: bRoot, scope: scope)
        let server = MockMutationServer()
        try a.set(Data([1]), forKey: "my-list")
        try b.set(nil, forKey: "my-list")
        try await a.flush(using: server, serverWins: server)
        try await b.flush(using: server, serverWins: server)
        #expect(b.values == a.values)
        #expect(b.pending.isEmpty)
        b.invalidate()
        let reopened = try DurableMutationStore(directory: bRoot, scope: scope)
        #expect(reopened.values == a.values)
        #expect(reopened.pending.isEmpty)
        try reopened.set(nil, forKey: "my-list")
        try await reopened.flush(using: server, serverWins: server)
        try await a.flush(using: server, serverWins: server)
        #expect(a.values.isEmpty)
        #expect(await server.revision(for: scope) == 2)
    }

    actor SuspendedSnapshot: MutationSnapshotSource {
        let result: MutationSnapshot
        var waiting: CheckedContinuation<MutationSnapshot, Never>?
        var started = false
        init(_ result: MutationSnapshot) { self.result = result }
        func snapshot(for scope: MutationScope) async throws -> MutationSnapshot {
            started = true
            return await withCheckedContinuation { waiting = $0 }
        }
        func release() { waiting?.resume(returning: result); waiting = nil }
    }

    @Test func editDuringSnapshotIsNotDiscarded() async throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let source = SuspendedSnapshot(MutationSnapshot(scope: scope, revision: 0, values: [:]))
        let task = Task { try await queue.flush(using: MockMutationServer(), serverWins: source) }
        while !(await source.started) { await Task.yield() }
        try queue.set(Data([9]), forKey: "my-list")
        let pending = queue.pending
        await source.release()
        do { try await task.value; Issue.record("Expected stale snapshot rejection") } catch { }
        #expect(queue.pending == pending)
        #expect(queue.values["my-list"] == Data([9]))
    }

    @Test func logoutDuringSnapshotCannotRecreateJournal() async throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let source = SuspendedSnapshot(MutationSnapshot(scope: scope, revision: 2, values: ["secret": Data([1])]))
        let task = Task { try await queue.flush(using: MockMutationServer(), serverWins: source) }
        while !(await source.started) { await Task.yield() }
        try queue.deleteLocalData()
        await source.release()
        do { try await task.value; Issue.record("Expected inactive error") } catch { }
        #expect(queue.values.isEmpty)
        let recreated = try DurableMutationStore(directory: dir, scope: scope)
        #expect(recreated.values.isEmpty)
    }

    struct FixedSnapshot: MutationSnapshotSource {
        let value: MutationSnapshot
        func snapshot(for scope: MutationScope) async throws -> MutationSnapshot { value }
    }
    @Test func wrongScopeAndRegressingRevisionAreRejected() async throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let server = MockMutationServer()
        try queue.set(Data([1]), forKey: "my-list")
        try await queue.flush(using: server)
        for value in [MutationSnapshot(scope: MutationScope(accountID: "other", profileID: "adult-a"), revision: 1, values: [:]),
                      MutationSnapshot(scope: scope, revision: 0, values: [:])] {
            do {
                try await queue.flush(using: server, serverWins: FixedSnapshot(value: value))
                Issue.record("Expected invalid snapshot")
            } catch { #expect(error as? MutationQueueError == .invalidReceipt) }
            #expect(queue.values["my-list"] == Data([1]))
        }
    }

    @Test func policyIsOptInAndConflictRetainsExactPending() async throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let server = MockMutationServer()
        _ = try await server.send(DurableMutation(id: UUID(), scope: scope, deviceID: UUID(),
            sequence: 1, baseRevision: 0, key: "my-list", value: Data([1])))
        try queue.set(nil, forKey: "my-list")
        let pending = queue.pending
        do { try await queue.flush(using: server); Issue.record("Expected conflict") }
        catch { #expect(error as? MutationQueueError == .conflict(currentRevision: 1)) }
        #expect(queue.pending == pending)
    }
    struct EditingConflictTransport: MutationTransport {
        let edit: @MainActor @Sendable () throws -> Void
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            try await edit()
            throw MutationQueueError.conflict(currentRevision: 1)
        }
    }
    @Test func editWhileSendIsInFlightSurvivesConflict() async throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        try queue.set(Data([1]), forKey: "my-list")
        let transport = EditingConflictTransport { try queue.set(Data([2]), forKey: "my-list") }
        let snapshot = FixedSnapshot(value: MutationSnapshot(scope: scope, revision: 1, values: [:]))
        do { try await queue.flush(using: transport, serverWins: snapshot); Issue.record("Expected changed batch rejection") }
        catch { #expect(error as? MutationQueueError == .invalidReceipt) }
        #expect(queue.pending.count == 2)
        #expect(queue.values["my-list"] == Data([2]))
    }

}
