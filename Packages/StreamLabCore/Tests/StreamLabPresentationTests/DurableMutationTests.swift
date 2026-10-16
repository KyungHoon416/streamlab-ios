import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B1 durable mutation journal")
@MainActor struct DurableMutationTests {
    private let scope = MutationScope(accountID: "account-a", profileID: "adult-a")
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func relaunchRestoresProjectionAndExactFIFOEnvelopes() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try DurableMutationStore(directory: dir, scope: scope)
        try first.set(Data("one".utf8), forKey: "my-list")
        try first.set(Data("two".utf8), forKey: "my-list")
        let envelopes = first.pending
        first.invalidate()
        let reopened = try DurableMutationStore(directory: dir, scope: scope)
        #expect(reopened.values["my-list"] == Data("two".utf8))
        #expect(reopened.pending == envelopes)
        #expect(envelopes.map(\.sequence) == [1, 2])
        let server = MockMutationServer()
        try await reopened.flush(using: server)
        #expect(reopened.pending.isEmpty)
        #expect(await server.revision(for: scope) == 2)
        let afterACK = try DurableMutationStore(directory: dir, scope: scope)
        #expect(afterACK.pending.isEmpty)
        #expect(afterACK.values == reopened.values)
        try afterACK.set(nil, forKey: "my-list")
        #expect(afterACK.pending.first?.sequence == 3)
        try await afterACK.flush(using: server)
        #expect(await server.values(for: scope).isEmpty)
    }

    @Test func lostAcknowledgementRetriesSameIDWithoutDoubleApply() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("saved".utf8), forKey: "my-list")
        let request = try #require(store.pending.first)
        let server = MockMutationServer()
        // Server commits, then the process dies before a local acknowledgement.
        _ = try await server.send(request)
        store.invalidate()
        let reopened = try DurableMutationStore(directory: dir, scope: scope)
        try await reopened.flush(using: server)
        #expect(await server.revision(for: scope) == 1)
        #expect(reopened.pending.isEmpty)
    }

    @Test func serverRelaunchRetainsIdempotencyReceipt() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("server.json")
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("saved".utf8), forKey: "my-list")
        let request = try #require(store.pending.first)
        let server = try MockMutationServer(storageURL: url)
        _ = try await server.send(request)
        let restarted = try MockMutationServer(storageURL: url)
        try await store.flush(using: restarted)
        #expect(await restarted.revision(for: scope) == 1)
        #expect(store.pending.isEmpty)
    }

    @Test func singleFlightIncludesMutationQueuedDuringSend() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("first".utf8), forKey: "my-list")
        let transport = HeldTransport()
        let running = Task { try await store.flush(using: transport) }
        await transport.waitForSend()
        try store.set(Data("second".utf8), forKey: "my-list")
        try await store.flush(using: transport)
        #expect(await transport.calls == 1)
        await transport.release()
        try await running.value
        #expect(await transport.calls == 2)
        #expect(store.pending.isEmpty)
    }

    @Test func cancellationAfterServerCommitKeepsRequestForRetry() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("saved".utf8), forKey: "my-list")
        let before = store.pending
        let transport = HeldTransport()
        let running = Task { try await store.flush(using: transport) }
        await transport.waitForSend()
        running.cancel()
        await transport.release()
        do { try await running.value; Issue.record("Cancelled flush acknowledged") }
        catch { #expect(error is CancellationError) }
        #expect(store.pending == before)
        try await store.flush(using: transport)
        #expect(store.pending.isEmpty)
        #expect(await transport.server.revision(for: scope) == 1)
    }

    @Test func logoutDuringSendCannotRecreateJournal() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("saved".utf8), forKey: "my-list")
        let transport = HeldTransport()
        let running = Task { try await store.flush(using: transport) }
        await transport.waitForSend()
        try store.deleteLocalData()
        await transport.release()
        do { try await running.value; Issue.record("Inactive store acknowledged") }
        catch { #expect(error as? MutationQueueError == .inactive) }
        let reopened = try DurableMutationStore(directory: dir, scope: scope)
        #expect(reopened.values.isEmpty && reopened.pending.isEmpty)
    }

    @Test func changedPayloadAndOldSequenceAreRejected() async throws {
        let server = MockMutationServer()
        let id = UUID()
        let device = UUID()
        let original = DurableMutation(id: id, scope: scope, deviceID: device,
            sequence: 1, baseRevision: 0, key: "my-list", value: Data("one".utf8))
        _ = try await server.send(original)
        let altered = DurableMutation(id: id, scope: scope, deviceID: device,
            sequence: 1, baseRevision: 0, key: "my-list", value: Data("two".utf8))
        do { _ = try await server.send(altered); Issue.record("Reused ID accepted") }
        catch { #expect(error as? MutationQueueError == .reusedID) }
        let old = DurableMutation(id: UUID(), scope: scope, deviceID: device,
            sequence: 1, baseRevision: 1, key: "my-list", value: nil)
        do { _ = try await server.send(old); Issue.record("Old sequence accepted") }
        catch { #expect(error as? MutationQueueError == .outOfOrder) }
        #expect(await server.revision(for: scope) == 1)
    }

    @Test func offlineAndConflictKeepLocalStateAndRequest() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("local".utf8), forKey: "my-list")
        let pending = store.pending
        do {
            try await store.flush(using: Offline())
            Issue.record("Offline send unexpectedly succeeded")
        } catch { #expect(error is Offline.Failure) }
        #expect(store.pending == pending)
        let server = MockMutationServer()
        _ = try await server.send(DurableMutation(id: UUID(), scope: scope, deviceID: UUID(),
            sequence: 1, baseRevision: 0, key: "my-list", value: Data("remote".utf8)))
        do {
            try await store.flush(using: server)
            Issue.record("Conflict unexpectedly acknowledged")
        } catch { #expect(error as? MutationQueueError == .conflict(currentRevision: 1)) }
        #expect(store.pending == pending)
        #expect(store.values["my-list"] == Data("local".utf8))
    }

    @Test func scopeIsolationMigrationAndDeletion() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir, scope: scope,
                                         seed: ["my-list": Data("legacy".utf8)])
        let b = try DurableMutationStore(directory: dir,
            scope: MutationScope(accountID: "account-b", profileID: scope.profileID))
        let c = try DurableMutationStore(directory: dir,
            scope: MutationScope(accountID: scope.accountID, profileID: "child"))
        #expect(b.values.isEmpty && c.values.isEmpty)
        let reopened = try DurableMutationStore(directory: dir, scope: scope,
                                                seed: ["my-list": Data("stale".utf8)])
        #expect(reopened.values == a.values)
        #expect(reopened.pending == a.pending)
        reopened.invalidate()
        try a.deleteLocalData()
        #expect(throws: MutationQueueError.inactive) { try a.set(Data(), forKey: "my-list") }
        let empty = try DurableMutationStore(directory: dir, scope: scope)
        #expect(empty.values.isEmpty && empty.pending.isEmpty)
        #expect(b.pending.isEmpty && c.pending.isEmpty)
    }

    @Test func missingJournalDoesNotPublishNewState() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data("saved".utf8), forKey: "my-list")
        let pending = store.pending
        // Make the journal unreadable by removing its directory.
        try FileManager.default.removeItem(at: dir)
        #expect(throws: (any Error).self) { try store.set(Data("new".utf8), forKey: "my-list") }
        #expect(store.values["my-list"] == Data("saved".utf8))
        #expect(store.pending == pending)
    }

    @Test func corruptJournalIsNotSilentlyReinitialized() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try DurableMutationStore(directory: dir, scope: scope)
        let enumerator = try #require(FileManager.default.enumerator(at: dir,
            includingPropertiesForKeys: nil))
        let file = try #require(enumerator.allObjects.compactMap { $0 as? URL }.first { $0.pathExtension == "json" })
        let corrupt = Data("not JSON".utf8)
        try corrupt.write(to: file)
        #expect(throws: (any Error).self) { _ = try DurableMutationStore(directory: dir, scope: scope) }
        #expect(try Data(contentsOf: file) == corrupt)
    }
}

private struct Offline: MutationTransport {
    struct Failure: Error {}
    func send(_ mutation: DurableMutation) async throws -> UInt64 { throw Failure() }
}

/// Explicit barriers exercise actor reentrancy without timing sleeps.
private actor HeldTransport: MutationTransport {
    let server = MockMutationServer()
    private(set) var calls = 0
    private var started: CheckedContinuation<Void, Never>?
    private var held: CheckedContinuation<Void, Never>?
    func send(_ mutation: DurableMutation) async throws -> UInt64 {
        calls += 1
        let revision = try await server.send(mutation)
        if calls == 1 {
            await withCheckedContinuation { continuation in
                held = continuation
                started?.resume()
                started = nil
            }
        }
        return revision
    }
    func waitForSend() async {
        if held != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { held?.resume(); held = nil }
}
