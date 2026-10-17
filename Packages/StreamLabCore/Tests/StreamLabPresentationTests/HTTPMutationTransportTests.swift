import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation

@Suite("B2 HTTP mutation adapter")
struct HTTPMutationTransportTests {
    private let endpoint = URL(string: "https://sync.example.invalid/v1")!
    private let scope = MutationScope(accountID: "a", profileID: "p")
    private func mutation() -> DurableMutation {
        DurableMutation(id: UUID(), scope: scope, deviceID: UUID(), sequence: 1,
                        baseRevision: 0, key: "key", value: Data([42]))
    }
    actor Probe {
        var requests: [URLRequest] = []
        var delays: [Double] = []
        var replies: [(Int, String, [String: String])]
        init(_ replies: [(Int, String, [String: String])]) { self.replies = replies }
        func execute(_ request: URLRequest) throws -> (Data, URLResponse) {
            requests.append(request)
            guard !replies.isEmpty else { throw URLError(.badServerResponse) }
            let reply = replies.removeFirst()
            return (Data(reply.1.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.0,
                httpVersion: "HTTP/1.1", headerFields: reply.2)!)
        }
        func record(_ delay: Double) { delays.append(delay) }
    }
    private func receipt(_ mutation: DurableMutation) -> String {
        "{\"id\":\"\(mutation.id.uuidString)\",\"revision\":1}"
    }
    private func transport(_ probe: Probe) throws -> HTTPMutationTransport {
        try HTTPMutationTransport(baseURL: endpoint, execute: { try await probe.execute($0) },
                                  now: { Date(timeIntervalSince1970: 0) })
    }

    @Test func retryPreservesWireEnvelopeAndHonorsHeaders() async throws {
        let envelope = mutation()
        let probe = Probe([(429, "", ["Retry-After": "7"]),
                           (503, "", ["Retry-After": "Thu, 01 Jan 1970 00:00:09 GMT"]),
                           (200, receipt(envelope), [:])])
        let retry = RetryingMutationTransport(base: try transport(probe),
            sleep: { await probe.record($0) }, random: { 1 })
        #expect(try await retry.send(envelope) == 1)
        #expect(await probe.delays == [7, 9])
        let requests = await probe.requests
        #expect(requests.count == 3)
        for request in requests {
            #expect(request.url?.absoluteString == "https://sync.example.invalid/v1/mutations")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == envelope.id.uuidString)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.httpBody == requests[0].httpBody)
            #expect(try JSONDecoder().decode(DurableMutation.self, from: #require(request.httpBody)) == envelope)
        }
    }

    @Test func retryAfterParsing() throws {
        let now = Date(timeIntervalSince1970: 10)
        #expect(try HTTPMutationTransport.retryAfter(nil, now: now) == nil)
        #expect(try HTTPMutationTransport.retryAfter(" 31 ", now: now) == 31)
        #expect(try HTTPMutationTransport.retryAfter("Thu, 01 Jan 1970 00:00:00 GMT", now: now) == 0)
        for text in ["", "-1", "1.5", "NaN", "tomorrow", String(repeating: "9", count: 400),
                     "Fri, 01 Jan 1970 00:00:00 GMT"] {
            #expect(throws: MutationWireError.invalidRetryAfter) {
                try HTTPMutationTransport.retryAfter(text, now: now)
            }
        }
    }

    @Test func terminalStatusesAndUnsafeHeadersDoNotRetry() async throws {
        for reply in [(401, "", [String: String]()), (302, "", [:]),
                      (429, "", ["Retry-After": "31"]), (503, "", ["Retry-After": "-1"])] {
            let probe = Probe([reply])
            let retry = RetryingMutationTransport(base: try transport(probe),
                sleep: { await probe.record($0) }, random: { 1 })
            do { _ = try await retry.send(mutation()); Issue.record("Expected failure") } catch { }
            #expect(await probe.requests.count == 1)
            #expect(await probe.delays.isEmpty)
        }
    }

    @Test func validatesReceiptsAndConflictRevision() async throws {
        let envelope = mutation()
        for body in ["{}", "{\"id\":\"\(UUID())\",\"revision\":1}",
                     "{\"id\":\"\(envelope.id)\",\"revision\":2}"] {
            let adapter = try transport(Probe([(200, body, [:])]))
            await #expect(throws: MutationQueueError.invalidReceipt) { try await adapter.send(envelope) }
        }
        let adapter = try transport(Probe([(409, "{\"currentRevision\":4}", [:])]))
        await #expect(throws: MutationQueueError.conflict(currentRevision: 4)) { try await adapter.send(envelope) }
        let invalid = try transport(Probe([(409, "{}", [:])]))
        await #expect(throws: MutationWireError.invalidPayload) { try await invalid.send(envelope) }
    }

    @Test func snapshotScopeAndRevisionBounds() async throws {
        let valid = "{\"scope\":{\"accountID\":\"a\",\"profileID\":\"p\"},\"revision\":4,\"values\":{\"key\":\"Kg==\"}}"
        let probe = Probe([(200, valid, [:])])
        let snapshot = try await transport(probe).snapshot(for: scope)
        #expect(snapshot.values["key"] == Data([42]))
        #expect(snapshot.myListRevisionFloor == 4)
        let request = try #require(await probe.requests.first)
        #expect(request.url?.path == "/v1/snapshot")
        #expect(try JSONDecoder().decode(MutationScope.self, from: #require(request.httpBody)) == scope)
        for body in [valid.replacingOccurrences(of: "\"p\"", with: "\"other\""),
                     String(valid.dropLast()) + ",\"myListRevisionFloor\":5}",
                     String(valid.dropLast()) + ",\"myListItemRevisions\":{\"deleted\":5}}"] {
            let adapter = try transport(Probe([(200, body, [:])]))
            await #expect(throws: MutationWireError.invalidPayload) { try await adapter.snapshot(for: scope) }
        }
    }

    @Test @MainActor func invalidReceiptRetainsPendingJournal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = try DurableMutationStore(directory: directory, scope: scope)
        try queue.set(Data([42]), forKey: "key")
        let pending = queue.pending
        let adapter = try transport(Probe([(200, "{}", [:])]))
        await #expect(throws: MutationQueueError.invalidReceipt) { try await queue.flush(using: adapter) }
        #expect(queue.pending == pending)
        queue.invalidate()
        let reopened = try DurableMutationStore(directory: directory, scope: scope)
        #expect(reopened.pending == pending)
    }

    @Test func rejectsEndpointsNonHTTPAndOversizedResponses() async throws {
        for url in ["http://example.invalid", "https://u:p@example.invalid", "https://example.invalid?q=1"] {
            #expect(throws: MutationWireError.invalidEndpoint) {
                try HTTPMutationTransport(baseURL: URL(string: url)!)
            }
        }
        let nonHTTP = try HTTPMutationTransport(baseURL: endpoint, execute: { request in
            (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        })
        await #expect(throws: MutationWireError.nonHTTPResponse) { try await nonHTTP.send(mutation()) }
        let oversized = try HTTPMutationTransport(baseURL: endpoint, execute: { request in
            (Data(repeating: 0, count: 4 * 1024 * 1024 + 1),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        await #expect(throws: MutationWireError.oversizedResponse) { try await oversized.send(mutation()) }
    }

    @Test func cancellationAfterResponseIsNotAcknowledged() async throws {
        let envelope = mutation()
        let body = Data(receipt(envelope).utf8)
        let adapter = try HTTPMutationTransport(baseURL: endpoint, execute: { request in
            withUnsafeCurrentTask { $0?.cancel() }
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let task = Task { try await adapter.send(envelope) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
