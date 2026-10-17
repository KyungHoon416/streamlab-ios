import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 seeded durable queue chaos")
@MainActor struct MutationChaosTests {
    struct Generator {
        var state: UInt64
        mutating func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % 8)
        }
    }
    enum Fault: Sendable, Equatable { case none, offline, lostACK }

    /// Oracle records only accepted requests, independently of server snapshots.
    actor Harness: MutationTransport, MutationSnapshotSource {
        var server: MockMutationServer
        let url: URL
        var receipts: [UUID: UInt64] = [:]
        var expected: [String: Data] = [:]
        var keyRevisions: [String: UInt64] = [:]
        var owners: [UInt64: UUID] = [:]
        var revision: UInt64 = 0
        init(url: URL) throws { self.url = url; server = try MockMutationServer(storageURL: url) }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            try await send(mutation, fault: .none)
        }
        func send(_ mutation: DurableMutation, fault: Fault) async throws -> UInt64 {
            await Task.yield() // Allow competing client sends to cross this boundary.
            if fault == .offline { throw URLError(.notConnectedToInternet) }
            let actual = try await server.send(mutation)
            if let previous = receipts[mutation.id] {
                guard actual == previous else { throw Check.receiptChanged }
            } else {
                guard owners[actual] == nil else { throw Check.duplicateEffect }
                owners[actual] = mutation.id
                revision = max(revision, actual)
                receipts[mutation.id] = actual
                // Actor continuations can resume in a different order from server commits.
                if actual > keyRevisions[mutation.key, default: 0] {
                    keyRevisions[mutation.key] = actual
                    expected[mutation.key] = mutation.value
                }
            }
            if fault == .lostACK { throw URLError(.timedOut) }
            return actual
        }
        func snapshot(for scope: MutationScope) async throws -> MutationSnapshot {
            await server.snapshot(for: scope)
        }
        func relaunchServer() throws { server = try MockMutationServer(storageURL: url) }
        func verify(_ scope: MutationScope) async throws {
            let snapshot = await server.snapshot(for: scope)
            guard snapshot.revision == revision, UInt64(receipts.count) == revision, snapshot.values == expected else { throw Check.serverDiverged }
        }
    }
    enum Check: Error { case receiptChanged, duplicateEffect, serverDiverged }
    struct Transport: MutationTransport {
        let harness: Harness
        let fault: Fault
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            try await harness.send(mutation, fault: fault)
        }
    }

    @Test func seededEventOrdersConvergeAfterRelaunchAndLostACK() async throws {
        let replay = ProcessInfo.processInfo.environment["STREAMLAB_CHAOS_SEED"]
        let seeds: [UInt64]
        if let replay {
            let value = try #require(UInt64(replay), "STREAMLAB_CHAOS_SEED must be an unsigned integer")
            seeds = [value]
        } else { seeds = Array(1...1000).map(UInt64.init) }
        for seed in seeds {
            var trace: [String] = []
            do { try await run(seed: seed, trace: &trace) }
            catch {
                Issue.record("Chaos seed=\(seed) events=\(trace.joined(separator: ",")) error=\(error)")
                throw error
            }
        }
        print("CHAOS PASS seeds=\(seeds.count) replay=\(replay ?? "1...1000") eventsPerSeed=24")
    }

    private func run(seed: UInt64, trace: inout [String]) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chaos-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = MutationScope(accountID: "chaos", profileID: "a")
        let aDir = root.appendingPathComponent("a"), bDir = root.appendingPathComponent("b")
        var a = try DurableMutationStore(directory: aDir, scope: scope)
        let b = try DurableMutationStore(directory: bDir, scope: scope)
        let server = try Harness(url: root.appendingPathComponent("server.json"))
        var random = Generator(state: seed)
        for index in 0..<24 {
            let event = random.next()
            trace.append("\(index):\(event)")
            switch event {
            case 0, 1:
                let queue = event == 0 ? a : b
                let data = index % 3 == 0 ? nil : Data("\(seed):\(index)".utf8)
                try queue.set(data, forKey: "item-\(index % 3)")
            case 2:
                try await a.flush(using: server, serverWins: server)
            case 3:
                try await b.flush(using: server, serverWins: server)
            case 4:
                let pending = a.pending
                do { try await a.flush(using: Transport(harness: server, fault: .lostACK), serverWins: server) }
                catch let error as URLError where error.code == .timedOut {
                    try #require(a.pending == pending, "Lost ACK must retain the exact request")
                }
            case 5:
                let pending = b.pending
                do { try await b.flush(using: Transport(harness: server, fault: .offline), serverWins: server) }
                catch let error as URLError where error.code == .notConnectedToInternet {
                    try #require(b.pending == pending, "Offline must retain the exact request")
                }
            case 6:
                let pending = a.pending, values = a.values
                a.invalidate()
                a = try DurableMutationStore(directory: aDir, scope: scope)
                try #require(a.pending == pending && a.values == values, "Relaunch must preserve journal")
            default:
                try await server.relaunchServer()
            }
            try await server.verify(scope)
        }
        // Guarantee a real interleaving in every seed, even if its random events were quiet.
        trace.append("concurrent-writes")
        try a.set(Data([1]), forKey: "race-a")
        try b.set(Data([2]), forKey: "race-b")
        let clientA = a
        async let first: Void = clientA.flush(using: server, serverWins: server)
        async let second: Void = b.flush(using: server, serverWins: server)
        _ = try await (first, second)
        try await a.flush(using: server, serverWins: server)
        try await b.flush(using: server, serverWins: server)
        try await server.verify(scope)
        let snapshot = try await server.snapshot(for: scope)
        try #require(a.pending.isEmpty && b.pending.isEmpty, "Recovery must drain both queues")
        try #require(a.values == snapshot.values && b.values == snapshot.values, "Both clients must converge")
        let stable = snapshot.revision
        try await a.flush(using: server, serverWins: server)
        try #require(try await server.snapshot(for: scope).revision == stable, "Repeated sync must have no effect")
    }
}
