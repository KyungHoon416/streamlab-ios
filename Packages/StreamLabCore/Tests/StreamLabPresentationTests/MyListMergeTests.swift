import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 item level My List merge")
@MainActor struct MyListMergeTests {
    let scope = MutationScope(accountID: "test", profileID: "adult-a")
    func title(_ id: String) throws -> CatalogTitle {
        let object: [String: Any] = ["id": id, "name": id, "synopsis": "test", "genre": "test",
            "year": 2026, "durationMinutes": 90, "kind": "movie", "rating": "ALL",
            "visualSeed": 1, "popularity": 1]
        return try JSONDecoder().decode(CatalogTitle.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func items(_ queue: DurableMutationStore) throws -> [CatalogTitle] {
        try queue.values["my-list"].map { try JSONDecoder().decode([CatalogTitle].self, from: $0) } ?? []
    }
    func set(_ id: String, _ saved: Bool, in queue: DurableMutationStore) throws {
        let item = try title(id)
        var updated = try items(queue).filter { $0.id != id }
        if saved { updated.insert(item, at: 0) }
        try queue.set(JSONEncoder().encode(updated), forKey: "my-list",
            myListChange: MyListChange(title: item, isSaved: saved, observedRevision: queue.committedRevision))
    }
    func sync(_ queue: DurableMutationStore, _ server: MockMutationServer) async throws {
        try await queue.flush(using: server, serverWins: server, mergeMyListItems: true)
    }
    func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    @Test func distinctOfflineChangesMergeAcrossRelaunch() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir.appendingPathComponent("a"), scope: scope)
        let bDir = dir.appendingPathComponent("b")
        let b = try DurableMutationStore(directory: bDir, scope: scope)
        let server = MockMutationServer()
        try set("one", true, in: a); try set("two", true, in: b)
        let pending = b.pending
        b.invalidate()
        let reopened = try DurableMutationStore(directory: bDir, scope: scope)
        #expect(reopened.pending == pending)
        try await sync(a, server); try await sync(reopened, server); try await sync(a, server)
        #expect(Set(try items(a).map(\.id)) == ["one", "two"])
        #expect(a.values == reopened.values)
        #expect(reopened.pending.isEmpty)
    }

    @Test func sameItemConflictKeepsServerButOtherItemSurvives() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir.appendingPathComponent("a"), scope: scope)
        let b = try DurableMutationStore(directory: dir.appendingPathComponent("b"), scope: scope)
        let server = MockMutationServer()
        try set("one", true, in: a); try await sync(a, server); try await sync(b, server)
        try set("one", false, in: b); try set("two", true, in: b)
        try set("one", true, in: a); try await sync(a, server)
        try await sync(b, server); try await sync(a, server)
        #expect(Set(try items(b).map(\.id)) == ["one", "two"])
        #expect(a.values == b.values)
    }

    @Test func deletedItemVersionSurvivesServerRelaunchAndPreventsResurrection() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir.appendingPathComponent("a"), scope: scope)
        let b = try DurableMutationStore(directory: dir.appendingPathComponent("b"), scope: scope)
        let url = dir.appendingPathComponent("server.json")
        let server = try MockMutationServer(storageURL: url)
        try set("one", true, in: b) // Observed absence at revision zero.
        try set("one", true, in: a); try await sync(a, server)
        try set("one", false, in: a); try await sync(a, server)
        let reopened = try MockMutationServer(storageURL: url)
        try await sync(b, reopened)
        #expect(try items(b).isEmpty)
        #expect(await reopened.snapshot(for: scope).myListItemRevisions?["one"] == 2)
    }

    actor ConflictAfterOwnACK: MutationTransport {
        let server: MockMutationServer
        let remote: DurableMutation
        var count = 0
        init(_ server: MockMutationServer, remote: DurableMutation) { self.server = server; self.remote = remote }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            count += 1
            if count == 2 { _ = try await server.send(remote) }
            return try await server.send(mutation)
        }
    }
    @Test func ownAcknowledgedAddDoesNotBlockQueuedRemoval() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let server = MockMutationServer()
        try set("one", true, in: queue); try set("one", false, in: queue)
        let two = try title("two")
        let remote = DurableMutation(id: UUID(), scope: scope, deviceID: UUID(), sequence: 1,
            baseRevision: 1, key: "my-list", value: try JSONEncoder().encode([title("one"), two]),
            myListChange: MyListChange(title: two, isSaved: true, observedRevision: 1))
        try await queue.flush(using: ConflictAfterOwnACK(server, remote: remote), serverWins: server, mergeMyListItems: true)
        #expect(try items(queue).map(\.id) == ["two"])
        #expect(queue.pending.isEmpty)
    }

    actor LoseACK: MutationTransport {
        let server: MockMutationServer
        init(_ server: MockMutationServer) { self.server = server }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            _ = try await server.send(mutation)
            throw URLError(.timedOut)
        }
    }
    @Test func lostACKDoesNotDuplicateItemOrRevision() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        let server = MockMutationServer()
        try set("one", true, in: queue)
        let pending = queue.pending
        do { try await queue.flush(using: LoseACK(server), serverWins: server, mergeMyListItems: true); Issue.record("Expected timeout") }
        catch { }
        #expect(queue.pending == pending)
        try await sync(queue, server)
        #expect(await server.revision(for: scope) == 1)
        #expect(try items(queue).map(\.id) == ["one"])
    }

    actor FailAfterConflict: MutationTransport {
        let server: MockMutationServer
        var attempts = 0
        init(_ server: MockMutationServer) { self.server = server }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            attempts += 1
            if attempts > 1 { throw URLError(.notConnectedToInternet) }
            return try await server.send(mutation)
        }
    }
    @Test func rebasedChangesSurviveSendFailureAndRelaunch() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir.appendingPathComponent("a"), scope: scope)
        let bDir = dir.appendingPathComponent("b")
        let b = try DurableMutationStore(directory: bDir, scope: scope)
        let server = MockMutationServer()
        try set("one", true, in: a); try await sync(a, server)
        try set("two", true, in: b)
        let original = b.pending
        do {
            try await b.flush(using: FailAfterConflict(server), serverWins: server, mergeMyListItems: true)
            Issue.record("Expected offline failure after rebase")
        } catch { }
        #expect(Set(try items(b).map(\.id)) == ["one", "two"])
        #expect(b.pending.count == 1)
        #expect(b.pending.first?.id != original.first?.id)
        let rebased = b.pending
        b.invalidate()
        let reopened = try DurableMutationStore(directory: bDir, scope: scope)
        #expect(reopened.pending == rebased)
        try await sync(reopened, server)
        #expect(reopened.pending.isEmpty)
        #expect(await server.revision(for: scope) == 2)
        #expect(Set(try items(reopened).map(\.id)) == ["one", "two"])
    }

    struct LegacySnapshot: MutationSnapshotSource {
        let scope: MutationScope
        func snapshot(for scope: MutationScope) -> MutationSnapshot {
            MutationSnapshot(scope: self.scope, revision: 1, values: [:])
        }
    }
    struct Conflict: MutationTransport {
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            throw MutationQueueError.conflict(currentRevision: 1)
        }
    }
    @Test func missingItemHistoryFallsBackToServerWins() async throws {
        let dir = root(); defer { try? FileManager.default.removeItem(at: dir) }
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        try set("one", true, in: queue)
        try await queue.flush(using: Conflict(), serverWins: LegacySnapshot(scope: scope), mergeMyListItems: true)
        #expect(try items(queue).isEmpty)
        #expect(queue.pending.isEmpty)
    }
}
