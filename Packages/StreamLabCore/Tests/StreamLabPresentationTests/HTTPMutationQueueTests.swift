import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation

@Suite("B2 HTTP durable queue integration", .enabled(if:
    ProcessInfo.processInfo.environment["STREAMLAB_MUTATION_FIXTURE_URL"] != nil))
struct HTTPMutationQueueTests {
    private struct Stats: Decodable {
        let revision: UInt64
        let effects: Int
        let snapshots: Int
        let requests: [String]
    }
    private struct Configuration: Encodable { let mode: String; let scope: MutationScope }
    private actor Delays {
        var values: [Double] = []
        func record(_ value: Double) { values.append(value) }
    }
    private struct Fixture {
        let url: URL
        let scope = MutationScope(accountID: "fixture", profileID: "adult")
        init() throws {
            let raw = try #require(ProcessInfo.processInfo.environment["STREAMLAB_MUTATION_FIXTURE_URL"])
            let base = try #require(URL(string: raw))
            try #require(base.scheme == "http" && base.host == "127.0.0.1")
            url = base.appendingPathComponent("case").appendingPathComponent(UUID().uuidString)
        }
        func post(_ path: String, body: Data) async throws -> Data {
            var request = URLRequest(url: url.appendingPathComponent(path), timeoutInterval: 5)
            request.httpMethod = "POST"; request.httpBody = body
            let (data, response) = try await HTTPMutationTransport.load(request)
            try #require((response as? HTTPURLResponse)?.statusCode == 200)
            return data
        }
        func configure(_ mode: String) async throws {
            _ = try await post("configure", body: JSONEncoder().encode(Configuration(mode: mode, scope: scope)))
        }
        func stats() async throws -> Stats {
            let data = try await post("stats", body: Data("{}".utf8))
            return try JSONDecoder().decode(Stats.self, from: data)
        }
        func adapter() throws -> HTTPMutationTransport {
            let local = url
            // Test-only URL routing. Keep adapter serialization and default socket loader intact.
            return try HTTPMutationTransport(baseURL: URL(string: "https://fixture.invalid")!, execute: { request in
                var routed = request
                routed.url = local.appendingPathComponent(try #require(request.url?.lastPathComponent))
                return try await HTTPMutationTransport.load(routed)
            })
        }
    }

    @Test @MainActor func lostAcknowledgementSurvivesReopenWithoutDuplicateEffect() async throws {
        let fixture = try Fixture(); try await fixture.configure("lost")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try DurableMutationStore(directory: directory, scope: fixture.scope)
        try queue.set(Data([42]), forKey: "key")
        let original = queue.pending
        do {
            try await queue.flush(using: fixture.adapter())
            Issue.record("Truncated ACK must fail before removing the journal entry")
        } catch { #expect(error is URLError) }
        #expect(queue.pending == original)
        queue.invalidate()
        let reopened = try DurableMutationStore(directory: directory, scope: fixture.scope)
        #expect(reopened.pending == original)
        try await reopened.flush(using: fixture.adapter())
        #expect(reopened.pending.isEmpty)
        #expect(reopened.committedRevision == 1)
        let stats = try await fixture.stats()
        #expect(stats.effects == 1 && stats.revision == 1)
        #expect(stats.requests.count >= 2)
        #expect(Set(stats.requests).count == 1)
        print("HTTP QUEUE PASS lost-ack")
    }

    @Test @MainActor func conflictAdoptsServerSnapshot() async throws {
        let fixture = try Fixture(); try await fixture.configure("conflict")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try DurableMutationStore(directory: directory, scope: fixture.scope)
        try queue.set(Data([42]), forKey: "key")
        let adapter = try fixture.adapter()
        try await queue.flush(using: adapter, serverWins: adapter)
        #expect(queue.pending.isEmpty)
        #expect(queue.values["key"] == Data("b".utf8))
        #expect(queue.committedRevision == 1)
        let stats = try await fixture.stats()
        #expect(stats.requests.count == 1 && stats.effects == 0 && stats.snapshots == 1)
        print("HTTP QUEUE PASS conflict")
    }

    @Test @MainActor func mixedStatusesRetryWithSameBodyAndBoundedBudget() async throws {
        for mode in ["retry", "exhaust"] {
            let fixture = try Fixture(); try await fixture.configure(mode)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let queue = try DurableMutationStore(directory: directory, scope: fixture.scope)
            try queue.set(Data([42]), forKey: "key")
            let original = queue.pending
            let delays = Delays()
            let retry = RetryingMutationTransport(base: try fixture.adapter(),
                sleep: { await delays.record($0) }, random: { 1 })
            do {
                try await queue.flush(using: retry)
                #expect(mode == "retry")
            } catch {
                #expect(mode == "exhaust")
                #expect(error is MutationHTTPError)
            }
            let stats = try await fixture.stats()
            #expect(stats.requests.count == (mode == "retry" ? 3 : 4))
            #expect(Set(stats.requests).count == 1)
            #expect(stats.effects == (mode == "retry" ? 1 : 0))
            #expect(await delays.values == (mode == "retry" ? [2, 2] : [2, 2, 4]))
            #expect(queue.pending == (mode == "retry" ? [] : original))
        }
        print("HTTP QUEUE PASS retry-budget")
    }

    @Test @MainActor func cancellationDuringBackoffPreservesQueue() async throws {
        let fixture = try Fixture(); try await fixture.configure("cancel")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try DurableMutationStore(directory: directory, scope: fixture.scope)
        try queue.set(Data([42]), forKey: "key")
        let original = queue.pending
        let retry = RetryingMutationTransport(base: try fixture.adapter(), sleep: { _ in
            withUnsafeCurrentTask { $0?.cancel() }
        }, random: { 1 })
        let task = Task { try await queue.flush(using: retry) }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(queue.pending == original)
        let stats = try await fixture.stats()
        #expect(stats.requests.count == 1 && stats.effects == 0)
        print("HTTP QUEUE PASS cancellation")
    }
}
