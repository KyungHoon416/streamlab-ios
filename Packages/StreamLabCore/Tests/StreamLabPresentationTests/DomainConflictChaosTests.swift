import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 seeded domain conflict chaos")
@MainActor struct DomainConflictChaosTests {
    /// First send pauses until B commits. The next send fails before or after commit.
    actor Gate: MutationTransport {
        let server: MockMutationServer
        let loseACK: Bool
        var attempts = 0
        var blocked: CheckedContinuation<Void, Never>?
        var observer: CheckedContinuation<Void, Never>?
        init(server: MockMutationServer, loseACK: Bool) { self.server = server; self.loseACK = loseACK }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            attempts += 1
            if attempts == 1 {
                await withCheckedContinuation { continuation in
                    blocked = continuation
                    observer?.resume(); observer = nil
                }
            } else if !loseACK { throw URLError(.notConnectedToInternet) }
            let revision = try await server.send(mutation)
            if loseACK { throw URLError(.timedOut) }
            return revision
        }
        func waitUntilBlocked() async {
            if blocked != nil { return }
            await withCheckedContinuation { observer = $0 }
        }
        func release() { blocked?.resume(); blocked = nil }
    }

    func title(_ id: String) throws -> CatalogTitle {
        let object: [String: Any] = ["id": id, "name": id, "synopsis": "test", "genre": "test",
            "year": 2026, "durationMinutes": 90, "kind": "movie", "rating": "ALL", "visualSeed": 1, "popularity": 1]
        return try JSONDecoder().decode(CatalogTitle.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func sync(_ queue: DurableMutationStore, _ transport: any MutationTransport,
              _ server: MockMutationServer) async throws {
        try await queue.flush(using: transport, serverWins: server, preservePlaybackRestarts: true,
                              preserveSearchDeletions: true, mergeMyListItems: true)
    }

    @Test func thousandMixedPolicyConflicts() async throws {
        let replay = ProcessInfo.processInfo.environment["STREAMLAB_CHAOS_SEED"]
        let seeds: [UInt64]
        if let replay { seeds = [try #require(UInt64(replay), "Invalid chaos seed")] }
        else { seeds = Array(1...1000).map(UInt64.init) }
        for seed in seeds {
            var random = MutationChaosTests.Generator(state: seed)
            let sameItem = random.next() % 2 == 0
            let restart = random.next() % 2 == 0
            let clearAll = random.next() % 2 == 0
            let following = random.next() % 2 == 0
            let loseACK = random.next() % 2 == 0
            let orderIndex = random.next() % 6
            let orders = [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]
            let order = orders[orderIndex]
            do {
                try await run(sameItem: sameItem, restart: restart, clearAll: clearAll,
                              following: following, loseACK: loseACK, order: order)
            } catch {
                Issue.record("Domain seed=\(seed) sameItem=\(sameItem) restart=\(restart) clearAll=\(clearAll) following=\(following) lostACK=\(loseACK) order=\(order) error=\(error)")
                throw error
            }
        }
        print("DOMAIN CHAOS PASS seeds=\(seeds.count) replay=\(replay ?? "1...1000")")
    }

    private func run(sameItem: Bool, restart: Bool, clearAll: Bool, following: Bool,
                     loseACK: Bool, order: [Int]) async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("domain-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let scope = MutationScope(accountID: "domain", profileID: "adult-a")
        let aDir = dir.appendingPathComponent("a")
        let a = try DurableMutationStore(directory: aDir, scope: scope)
        let b = try DurableMutationStore(directory: dir.appendingPathComponent("b"), scope: scope)
        let url = dir.appendingPathComponent("server.json")
        let server = try MockMutationServer(storageURL: url)
        let common = try title("common"), one = try title("one"), two = try title("two")
        try a.set(JSONEncoder().encode([common]), forKey: "my-list")
        try a.set(JSONEncoder().encode(["old"]), forKey: "recent-searches")
        try a.set(Data("30".utf8), forKey: "progress")
        try await sync(a, server, server); try await sync(b, server, server)
        for action in order {
            switch action {
            case 0:
                try a.set(JSONEncoder().encode(sameItem ? [] : [one, common]), forKey: "my-list",
                    myListChange: MyListChange(title: sameItem ? common : one, isSaved: !sameItem,
                                               observedRevision: a.committedRevision))
                try b.set(JSONEncoder().encode(sameItem ? [common] : [two, common]), forKey: "my-list",
                    myListChange: MyListChange(title: sameItem ? common : two, isSaved: true,
                                               observedRevision: b.committedRevision))
            case 1:
                try a.set(nil, forKey: "recent-searches", searchDeletion: clearAll ? .all : .term("old"))
                try b.set(JSONEncoder().encode(["new", "old"]), forKey: "recent-searches")
            default:
                try a.set(Data("0".utf8), forKey: "progress", intent: restart ? .restartPlayback : nil)
                if restart && following { try a.set(Data("30".utf8), forKey: "progress") }
                try b.set(Data("1400".utf8), forKey: "progress")
            }
        }
        let gate = Gate(server: server, loseACK: loseACK)
        let sending = Task { try await sync(a, gate, server) }
        await gate.waitUntilBlocked()
        do { try await sync(b, server, server) }
        catch { await gate.release(); _ = await sending.result; throw error }
        await gate.release()
        do { try await sending.value; Issue.record("Expected injected transport failure") }
        catch let error as URLError {
            try #require(error.code == (loseACK ? .timedOut : .notConnectedToInternet))
        }
        let retained = a.pending, projection = a.values
        try #require(!retained.isEmpty, "Failed rebase send must stay pending")
        a.invalidate()
        let reopened = try DurableMutationStore(directory: aDir, scope: scope)
        try #require(reopened.pending == retained && reopened.values == projection)
        let reopenedServer = try MockMutationServer(storageURL: url)
        try await sync(reopened, reopenedServer, reopenedServer)
        try await sync(b, reopenedServer, reopenedServer)
        let values = reopened.values
        let listData = try #require(values["my-list"])
        let ids = Set(try JSONDecoder().decode([CatalogTitle].self, from: listData).map(\.id))
        try #require(ids == (sameItem ? Set(["common"]) : Set(["common", "one", "two"])))
        let searches = try values["recent-searches"].map { try JSONDecoder().decode([String].self, from: $0) } ?? []
        try #require(searches == (clearAll ? [] : ["new"]))
        let expectedProgress = restart ? (following ? "30" : "0") : "1400"
        try #require(values["progress"] == Data(expectedProgress.utf8))
        try #require(reopened.pending.isEmpty && b.pending.isEmpty && values == b.values)
        let revision = await reopenedServer.revision(for: scope)
        try await sync(reopened, reopenedServer, reopenedServer)
        try #require(await reopenedServer.revision(for: scope) == revision)
    }
}
