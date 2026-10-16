import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 recent search deletion conflict")
@MainActor struct SearchConflictTests {
    @MainActor struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        func store(_ device: String, profile: String = "adult-a") -> RecentSearchStore {
            RecentSearchStore(profileID: profile, accountID: "test", directory: root.appendingPathComponent(device))
        }
        func clean() { try? FileManager.default.removeItem(at: root) }
    }
    func sync(_ store: RecentSearchStore, _ server: MockMutationServer) async throws {
        try await store.flush(using: server, snapshots: server)
    }

    @Test func staleSnapshotCannotResurrectServerDeletion() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        a.record("액션"); try await sync(a, server); try await sync(b, server)
        b.record("드라마") // Old snapshot still includes 액션.
        a.remove("액션"); try await sync(a, server)
        try await sync(b, server)
        #expect(b.terms.isEmpty)
        #expect(b.pendingMutations.isEmpty)
        b.record("액션") // A fresh, explicit search may add it again.
        try await sync(b, server); try await sync(a, server)
        #expect(a.terms == ["액션"])
    }

    @Test func offlineRemovalSurvivesRelaunchAndPreservesOtherServerTerms() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        a.record("Action"); try await sync(a, server); try await sync(b, server)
        b.remove(" action ")
        let pending = b.pendingMutations
        #expect(pending.first?.searchDeletion == .term("action"))
        a.record("드라마"); try await sync(a, server)
        b.invalidate()
        let reopened = f.store("b")
        #expect(reopened.pendingMutations == pending)
        try await sync(reopened, server); try await sync(a, server)
        #expect(reopened.terms == ["드라마"])
        #expect(a.terms == reopened.terms)
    }

    @Test func offlineClearWinsConflictAndDoesNotAffectOtherProfile() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), other = f.store("a", profile: "adult-b")
        let server = MockMutationServer()
        a.record("액션"); try await sync(a, server); try await sync(b, server)
        other.record("별도"); try await sync(other, server)
        b.clear(); a.record("새 검색"); try await sync(a, server)
        b.invalidate()
        let reopened = f.store("b")
        try await sync(reopened, server); try await sync(a, server); try await sync(other, server)
        #expect(a.terms.isEmpty)
        #expect(reopened.terms.isEmpty)
        #expect(other.terms == ["별도"])
    }

    actor FailRebasedSend: MutationTransport {
        let server: MockMutationServer
        var count = 0
        init(_ server: MockMutationServer) { self.server = server }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            count += 1
            if count > 1 { throw URLError(.notConnectedToInternet) }
            return try await server.send(mutation)
        }
    }
    @Test func rebasedDeletionIsAtomicAndSurvivesFailedSend() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), b = f.store("b"), server = MockMutationServer()
        a.record("액션"); try await sync(a, server); try await sync(b, server)
        b.remove("액션")
        let oldID = b.pendingMutations.first?.id
        a.record("새 검색"); try await sync(a, server)
        do { try await b.flush(using: FailRebasedSend(server), snapshots: server); Issue.record("Expected offline") }
        catch { }
        #expect(b.terms == ["새 검색"])
        let rebased = b.pendingMutations
        #expect(rebased.count == 1)
        #expect(rebased.first?.id != oldID)
        #expect(rebased.first?.searchDeletion == .term("액션"))
        b.invalidate()
        let reopened = f.store("b")
        #expect(reopened.pendingMutations == rebased)
        try await sync(reopened, server); try await sync(a, server)
        #expect(a.terms == ["새 검색"])
    }

    actor LoseACK: MutationTransport {
        let server: MockMutationServer
        init(_ server: MockMutationServer) { self.server = server }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            _ = try await server.send(mutation)
            throw URLError(.timedOut)
        }
    }
    @Test func deletionACKLossDoesNotApplyTwice() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), server = MockMutationServer()
        a.record("액션"); try await sync(a, server)
        a.clear()
        let pending = a.pendingMutations
        do { try await a.flush(using: LoseACK(server), snapshots: server); Issue.record("Expected lost ACK") }
        catch { }
        #expect(a.pendingMutations == pending)
        try await sync(a, server)
        #expect(a.pendingMutations.isEmpty)
        #expect(await server.revision(for: MutationScope(accountID: "test", profileID: "adult-a")) == 2)
    }

    actor SuspendedSnapshot: MutationSnapshotSource {
        var started = false
        var continuation: CheckedContinuation<MutationSnapshot, Never>?
        let scope = MutationScope(accountID: "test", profileID: "adult-a")
        func snapshot(for scope: MutationScope) async throws -> MutationSnapshot {
            started = true
            return await withCheckedContinuation { continuation = $0 }
        }
        func release() {
            continuation?.resume(returning: MutationSnapshot(scope: scope, revision: 0, values: [:]))
            continuation = nil
        }
    }
    @Test func profileInvalidationDuringFetchCannotPublishHistory() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), source = SuspendedSnapshot()
        let task = Task { try await a.flush(using: MockMutationServer(), snapshots: source) }
        while !(await source.started) { await Task.yield() }
        a.invalidate(); await source.release()
        do { try await task.value; Issue.record("Expected inactive") } catch { }
        #expect(a.terms.isEmpty)
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
    @Test func repeatedConflictKeepsDeletionWithFiniteAttempts() async throws {
        let f = Fixture(); defer { f.clean() }
        let a = f.store("a"), server = AlwaysConflict()
        a.record("액션"); a.clear()
        do { try await a.flush(using: server, snapshots: server); Issue.record("Expected conflict budget") }
        catch { }
        #expect(await server.attempts == 4)
        #expect(a.pendingMutations.count == 1)
        #expect(a.pendingMutations.first?.searchDeletion == .all)
        let pending = a.pendingMutations
        a.invalidate()
        #expect(f.store("a").pendingMutations == pending)
    }

}
