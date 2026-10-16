import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 durable progress conflict")
@MainActor struct ProgressConflictTests {
    struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        func store(_ device: String) -> PlaybackProgressStore {
            PlaybackProgressStore(profileID: "adult-a", durable: true,
                directory: root.appendingPathComponent(device), accountID: "test-account")
        }
        func clean() { try? FileManager.default.removeItem(at: root) }
    }
    func save(_ store: PlaybackProgressStore, _ position: Double) {
        store.save(titleID: "movie", sourceID: "hls", position: position, duration: 3600)
    }
    func position(_ store: PlaybackProgressStore) -> Double? {
        store.position(titleID: "movie", sourceID: "hls", duration: 3600)
    }

    @Test func staleCheckpointCannotOverwriteAcceptedProgressOrWriteAgain() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        save(a, 1400); save(b, 30)
        try await a.flush(using: server, snapshots: server)
        try await b.flush(using: server, snapshots: server)
        #expect(position(b) == 1400)
        #expect(b.requiresReload)
        save(b, 31)
        #expect(b.pendingMutations.isEmpty)
        #expect(position(b) == 1400)
        b.invalidate()
        let reopened = f.store("b")
        #expect(position(reopened) == 1400)
        #expect(!reopened.requiresReload)
    }

    @Test func offlineRestartAndFollowingProgressSurviveRelaunchAndConflict() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        save(a, 1400)
        try await a.flush(using: server, snapshots: server)
        save(b, 30)
        b.restart(titleID: "movie", sourceID: "hls")
        save(b, 4)
        let pending = b.pendingMutations
        #expect(pending[1].intent == .restartPlayback)
        b.invalidate()
        let reopened = f.store("b")
        #expect(reopened.pendingMutations == pending)
        try await reopened.flush(using: server, snapshots: server)
        #expect(reopened.pendingMutations.isEmpty)
        #expect(position(reopened) == 4)
        try await a.flush(using: server, snapshots: server)
        #expect(position(a) == 4)
        #expect(await server.revision(for: MutationScope(accountID: "test-account", profileID: "adult-a")) == 3)
    }

    @Test func explicitRestartWinsButZeroCheckpointDoesNot() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        save(a, 1400)
        try await a.flush(using: server, snapshots: server)
        save(b, 0)
        #expect(b.pendingMutations.first?.intent == nil)
        try await b.flush(using: server, snapshots: server)
        #expect(position(b) == 1400)
        b.restart(titleID: "movie", sourceID: "hls")
        #expect(!b.requiresReload)
        try await b.flush(using: server, snapshots: server)
        try await a.flush(using: server, snapshots: server)
        #expect(position(a) == nil)
    }

    actor LoseACK: MutationTransport {
        let server: MockMutationServer
        var lost = false
        init(_ server: MockMutationServer) { self.server = server }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            let revision = try await server.send(mutation)
            if !lost { lost = true; throw URLError(.timedOut) }
            return revision
        }
    }
    @Test func restartACKLossRetainsExactEnvelopeAndOneEffect() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), server = MockMutationServer()
        a.restart(titleID: "movie", sourceID: "hls")
        let pending = a.pendingMutations
        do { try await a.flush(using: LoseACK(server), snapshots: server); Issue.record("Expected timeout") }
        catch { }
        #expect(a.pendingMutations == pending)
        a.invalidate()
        let reopened = f.store("a")
        try await reopened.flush(using: server, snapshots: server)
        #expect(await server.revision(for: MutationScope(accountID: "test-account", profileID: "adult-a")) == 1)
        #expect(reopened.pendingMutations.isEmpty)
    }

    actor AlwaysConflict: MutationTransport, MutationSnapshotSource {
        var revision: UInt64 = 0
        var attempts = 0
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            attempts += 1; revision = mutation.baseRevision + 1
            throw MutationQueueError.conflict(currentRevision: revision)
        }
        func snapshot(for scope: MutationScope) -> MutationSnapshot {
            MutationSnapshot(scope: scope, revision: revision, values: [:])
        }
    }
    @Test func repeatedConflictsAreBoundedAndRetainRestartOnDisk() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), server = AlwaysConflict()
        a.restart(titleID: "movie", sourceID: "hls")
        do { try await a.flush(using: server, snapshots: server); Issue.record("Expected conflict limit") }
        catch { }
        #expect(await server.attempts == 4)
        #expect(a.pendingMutations.count == 1)
        #expect(a.pendingMutations.first?.intent == .restartPlayback)
        let pending = a.pendingMutations
        a.invalidate()
        #expect(f.store("a").pendingMutations == pending)
    }

    @Test func oldEnvelopeDecodesWithoutRestartIntent() throws {
        let item = DurableMutation(id: UUID(), scope: MutationScope(accountID: "a", profileID: "p"),
            deviceID: UUID(), sequence: 1, baseRevision: 0, key: "k", value: nil)
        let encoded = try JSONEncoder().encode(item)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "intent")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(DurableMutation.self, from: oldData) == item)
    }
}
