import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B1 durable recent searches")
@MainActor struct RecentSearchStoreTests {
    @MainActor private struct Fixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        func store(profile: String = "adult-a", account: String = "local-demo") -> RecentSearchStore {
            RecentSearchStore(profileID: profile, accountID: account, directory: directory)
        }
        func clean() { try? FileManager.default.removeItem(at: directory) }
    }

    @Test func normalizesDeduplicatesAndMovesRepeatedSearchToFront() {
        let f = Fixture()
        defer { f.clean() }
        let store = f.store()
        store.record("  Space\n   Travel  ")
        store.record("액션")
        store.record("space travel")
        #expect(store.terms == ["space travel", "액션"])
        #expect(store.pendingMutations.count == 3)
        var retrySignals = 0
        store.onMutation = { retrySignals += 1 }
        store.record("space travel")
        store.record(" \n\t")
        #expect(store.pendingMutations.count == 3)
        #expect(retrySignals == 1)
    }

    @Test func historyAndEachTermAreBounded() {
        let f = Fixture()
        defer { f.clean() }
        let store = f.store()
        for index in 0..<25 { store.record("검색어 \(index)") }
        #expect(store.terms.count == 20)
        #expect(store.terms.first == "검색어 24")
        #expect(store.terms.last == "검색어 5")
        store.record(String(repeating: "가", count: 150))
        #expect(store.terms.first?.count == 100)
    }

    @Test func offlineRelaunchRestoresHistoryAndIdenticalRequests() async throws {
        let f = Fixture()
        defer { f.clean() }
        let store = f.store()
        store.record("액션")
        store.record("드라마")
        let pending = store.pendingMutations
        do { try await store.flush(using: SearchOfflineTransport()); Issue.record("Offline send succeeded") }
        catch { #expect(error is SearchOfflineTransport.Failure) }
        store.invalidate()
        let reopened = f.store()
        #expect(reopened.terms == ["드라마", "액션"])
        #expect(reopened.pendingMutations == pending)
        let server = MockMutationServer()
        // Simulate an ACK lost after the server committed the first request.
        let head = try #require(reopened.pendingMutations.first)
        _ = try await server.send(head)
        try await reopened.flush(using: server)
        #expect(reopened.pendingMutations.isEmpty)
        #expect(await server.revision(for: head.scope) == 2)
        #expect(f.store().terms == ["드라마", "액션"])
    }

    @Test func individualAndAllDeletionSurviveRelaunchAndReachServer() async throws {
        let f = Fixture()
        defer { f.clean() }
        let store = f.store()
        store.record("액션")
        store.record("드라마")
        store.remove("액션")
        #expect(store.terms == ["드라마"])
        #expect(f.store().terms == ["드라마"])
        store.clear()
        #expect(store.pendingMutations.count == 4)
        let last = try #require(store.pendingMutations.last)
        #expect(last.value == nil)
        let server = MockMutationServer()
        try await store.flush(using: server)
        #expect(await server.values(for: last.scope).isEmpty)
        #expect(f.store().terms.isEmpty)
        store.clear()
        #expect(store.pendingMutations.isEmpty)
    }

    @Test func accountAndProfileIsolationAndInvalidation() {
        let f = Fixture()
        defer { f.clean() }
        let a = f.store()
        a.record("액션")
        let b = f.store(profile: "kids")
        let c = f.store(account: "other")
        #expect(b.terms.isEmpty && c.terms.isEmpty)
        b.record("애니메이션")
        b.clear()
        a.invalidate()
        a.record("must not persist")
        a.clear()
        #expect(a.terms.isEmpty)
        #expect(f.store().terms == ["액션"])
        #expect(f.store().pendingMutations.count == 1)
    }

    @Test func failedSaveKeepsPublishedHistoryAndPendingRequest() throws {
        let f = Fixture()
        defer { f.clean() }
        let store = f.store()
        store.record("액션")
        let pending = store.pendingMutations
        try FileManager.default.removeItem(at: f.directory)
        store.record("드라마")
        #expect(store.persistenceError != nil)
        #expect(store.terms == ["액션"])
        #expect(store.pendingMutations == pending)
    }

    @Test func malformedSnapshotIsNotOverwrittenByNewSearch() throws {
        let f = Fixture()
        defer { f.clean() }
        let queue = try DurableMutationStore(directory: f.directory,
            scope: MutationScope(accountID: "local-demo", profileID: "adult-a"))
        let invalid = Data("not JSON".utf8)
        try queue.set(invalid, forKey: "recent-searches")
        let store = f.store()
        #expect(store.persistenceError != nil)
        store.record("액션")
        #expect(store.persistenceError != nil)
        try queue.refresh()
        #expect(queue.values["recent-searches"] == invalid)
        #expect(queue.pending.count == 1)
    }
}

private struct SearchOfflineTransport: MutationTransport {
    struct Failure: Error {}
    func send(_ mutation: DurableMutation) async throws -> UInt64 { throw Failure() }
}
