import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 bounded mutation retry")
struct MutationRetryTests {
    actor Probe: MutationTransport {
        var requests: [DurableMutation] = []
        var delays: [Double] = []
        var failures: [any Error & Sendable]
        let server = MockMutationServer()
        let loseFirstACK: Bool
        init(_ failures: [any Error & Sendable] = [], loseFirstACK: Bool = false) {
            self.failures = failures
            self.loseFirstACK = loseFirstACK
        }
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            requests.append(mutation)
            if !failures.isEmpty { throw failures.removeFirst() }
            let revision = try await server.send(mutation)
            if loseFirstACK && requests.count == 1 { throw URLError(.timedOut) }
            return revision
        }
        func record(_ delay: Double) { delays.append(delay) }
    }
    private func request() -> DurableMutation {
        DurableMutation(id: UUID(), scope: MutationScope(accountID: "a", profileID: "p"),
            deviceID: UUID(), sequence: 1, baseRevision: 0, key: "key", value: Data([1]))
    }
    private func retry(_ probe: Probe) -> RetryingMutationTransport {
        RetryingMutationTransport(base: probe, sleep: { await probe.record($0) }, random: { 1 })
    }

    @Test func mixedFailuresRespectRetryAfterAndExactEnvelope() async throws {
        let probe = Probe([MutationHTTPError.status(429, retryAfter: 7),
                           MutationHTTPError.status(503, retryAfter: nil), URLError(.timedOut)])
        let envelope = request()
        #expect(try await retry(probe).send(envelope) == 1)
        #expect(await probe.requests == Array(repeating: envelope, count: 4))
        #expect(await probe.delays == [7, 2, 4])
    }

    @Test func lostACKHasOneServerEffect() async throws {
        let probe = Probe(loseFirstACK: true)
        let envelope = request()
        #expect(try await retry(probe).send(envelope) == 1)
        #expect(await probe.requests.count == 2)
        #expect(await probe.server.revision(for: envelope.scope) == 1)
    }

    @Test func terminalErrorsAndLongRetryAfterDoNotSpin() async {
        let errors: [any Error & Sendable] = [MutationQueueError.conflict(currentRevision: 8),
            MutationHTTPError.status(401, retryAfter: nil),
            MutationHTTPError.status(429, retryAfter: 31),
            MutationHTTPError.status(429, retryAfter: .nan), URLError(.cancelled)]
        for error in errors {
            let probe = Probe([error])
            do { _ = try await retry(probe).send(request()); Issue.record("Expected terminal error") }
            catch { }
            #expect(await probe.requests.count == 1)
            #expect(await probe.delays.isEmpty)
        }
    }

    @Test @MainActor func exhaustedBudgetKeepsJournalAcrossRelaunch() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let scope = MutationScope(accountID: "a", profileID: "p")
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        try queue.set(Data([42]), forKey: "key")
        let pending = queue.pending
        let probe = Probe(Array(repeating: URLError(.timedOut), count: 4))
        do { try await queue.flush(using: retry(probe)); Issue.record("Expected exhausted budget") }
        catch { }
        #expect(await probe.requests.count == 4)
        #expect(await probe.delays == [1, 2, 4])
        queue.invalidate()
        let reopened = try DurableMutationStore(directory: dir, scope: scope)
        #expect(reopened.pending == pending)
        try await reopened.flush(using: MockMutationServer())
        #expect(reopened.pending.isEmpty)
    }

    @Test func cancellationDuringBackoffPreventsNextSend() async throws {
        let probe = Probe([URLError(.timedOut)])
        let envelope = request()
        let transport = RetryingMutationTransport(base: probe, sleep: { delay in
            await probe.record(delay)
            withUnsafeCurrentTask { $0?.cancel() }
        }, random: { 0 })
        let task = Task { try await transport.send(envelope) }
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
        #expect(await probe.requests.count == 1)
        #expect(await probe.delays == [0.5])
    }
}
