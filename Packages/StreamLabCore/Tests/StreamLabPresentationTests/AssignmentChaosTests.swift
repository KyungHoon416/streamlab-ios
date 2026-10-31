import Foundation
import Testing
import StreamLabDomain
import StreamLabCatalogData
import StreamLabPresentation

private actor FiveHomeReplies: CatalogRepository {
    private var replies: [Int: CheckedContinuation<HomeSnapshot, Never>] = [:]
    private var started: [Int: CheckedContinuation<Void, Never>] = [:]
    private var count = 0
    func home(profile: ViewerProfile) async throws -> HomeSnapshot {
        count += 1
        let index = count
        return await withCheckedContinuation {
            replies[index] = $0
            started.removeValue(forKey: index)?.resume()
        }
    }
    func wait(_ index: Int) async {
        if replies[index] != nil { return }
        await withCheckedContinuation { started[index] = $0 }
    }
    func finish(_ index: Int, _ value: HomeSnapshot) { replies.removeValue(forKey: index)!.resume(returning: value) }
    func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? { nil }
    func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage { .init(items: [], nextCursor: nil) }
    func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage { .init(items: [], nextCursor: nil) }
}

@Suite("Assignment exact F01 and F03", .timeLimit(.minutes(1)))
@MainActor struct AssignmentChaosTests {
    @Test func fiveHomeRefreshesReverseRepliesKeepLatestAndUniqueCards() async throws {
        let profile = ViewerProfile.demo[0]
        let items = try await MockCatalogRepository(responseDelay: .zero).browse(profile: profile, after: nil, limit: 5).items
        let repository = FiveHomeReplies()
        let store = CatalogStore(profile: profile, repository: repository)
        var tasks: [Task<Void, Never>] = []
        for index in 1...5 {
            tasks.append(store.loadHome())
            await repository.wait(index)
        }
        for index in (1...5).reversed() {
            let item = items[index - 1]
            let rail = ContentRail(id: "rail", title: "test", items: [item, item])
            let progress = ContinueWatchingItem(title: item, positionSeconds: 5, durationSeconds: 30)
            await repository.finish(index, .init(hero: item, rails: [rail, rail], continueWatching: [progress, progress]))
            await tasks[index - 1].value
            let home = try #require(store.home)
            try #require(home.hero.id == items[4].id)
            try #require(home.rails.count == 1)
            try #require(home.rails[0].items.map(\.id) == [items[4].id])
            try #require(home.continueWatching.map(\.id) == [items[4].id])
            try #require(!store.loading)
        }
        print("F01 PASS order=5,4,3,2,1 latest=5 duplicates=0")
    }

    @Test func hundredQueuedMutationsRecoverAfterAllServerACKsAreLost() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("f03-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = MutationScope(accountID: "f03", profileID: "adult")
        let local = root.appendingPathComponent("local")
        let serverURL = root.appendingPathComponent("server.json")
        let store = try DurableMutationStore(directory: local, scope: scope)
        for index in 0..<100 { try store.set(Data("value-\(index)".utf8), forKey: "item-\(index)") }
        let expected = store.values
        let envelopes = store.pending
        try #require(envelopes.count == 100)
        let server = try MockMutationServer(storageURL: serverURL)
        // All server effects commit, but no local ACK is recorded before reconstruction.
        for envelope in envelopes { _ = try await server.send(envelope) }
        store.invalidate()
        let reopened = try DurableMutationStore(directory: local, scope: scope)
        let restartedServer = try MockMutationServer(storageURL: serverURL)
        try #require(reopened.pending == envelopes)
        try await reopened.flush(using: restartedServer)
        try #require(reopened.pending.isEmpty)
        try #require(reopened.values == expected)
        try #require(await restartedServer.values(for: scope) == expected)
        try #require(await restartedServer.revision(for: scope) == 100)
        let again = try DurableMutationStore(directory: local, scope: scope)
        try #require(again.pending.isEmpty)
        try #require(again.values == expected)
        print("F03 PASS mutations=100 serverEffects=100 pending=0 lost=0 replay=all-acks-lost")
    }
}
