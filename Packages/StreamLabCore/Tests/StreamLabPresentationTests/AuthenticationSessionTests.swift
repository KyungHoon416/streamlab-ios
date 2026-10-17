import Foundation
import Testing
@testable import StreamLabPresentation

@Suite("B3 authentication single flight", .timeLimit(.minutes(1)))
struct AuthenticationSessionTests {
    private enum Fault: Error { case server500 }
    private actor Gate {
        private var result: Result<String, Fault>?
        private var callbacks: [CheckedContinuation<String, any Error>] = []
        var calls = 0
        func wait() async throws -> String {
            calls += 1
            if let result { return try result.get() }
            // Intentionally ignores cancellation to test rejection of late completion.
            return try await withCheckedThrowingContinuation { callbacks.append($0) }
        }
        func finish(_ value: Result<String, Fault>) {
            result = value
            let saved = callbacks; callbacks.removeAll()
            for callback in saved {
                switch value {
                case .success(let token): callback.resume(returning: token)
                case .failure(let error): callback.resume(throwing: error)
                }
            }
        }
    }
    private actor Server {
        var requests: [URLRequest] = []
        let always401: Bool
        init(always401: Bool = false) { self.always401 = always401 }
        func execute(_ request: URLRequest) -> (Data, URLResponse) {
            requests.append(request)
            let status = always401 || request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" ? 401 : 200
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }
    private func request() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://auth.example.invalid/mutations")!)
        request.httpMethod = "POST"; request.httpBody = Data("immutable-body".utf8)
        request.setValue("stable-id", forHTTPHeaderField: "Idempotency-Key")
        return request
    }
    private func client(_ session: AuthenticationSession, _ server: Server) throws -> AuthenticatedHTTPClient {
        try AuthenticatedHTTPClient(origin: URL(string: "https://auth.example.invalid")!, session: session,
                                    transport: { await server.execute($0) })
    }
    private func waitUntil(_ condition: () async -> Bool) async throws {
        let clock = ContinuousClock(); let limit = clock.now.advanced(by: .seconds(5))
        while !(await condition()) {
            guard clock.now < limit else { Issue.record("Concurrency barrier timed out"); throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    @Test func eight401sShareOneRefreshAndReplayExactRequests() async throws {
        let gate = Gate(); let server = Server()
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let client = try client(session, server); let request = request()
        let tasks = (0..<8).map { _ in Task { try await client.execute(request) } }
        try await waitUntil {
            let count = await session.waitingCount
            let calls = await gate.calls
            return count == 8 && calls == 1
        }
        #expect(await gate.calls == 1)
        await gate.finish(.success("renewed"))
        for task in tasks { #expect((try await task.value.1 as? HTTPURLResponse)?.statusCode == 200) }
        let requests = await server.requests
        #expect(requests.count == 16)
        #expect(requests.filter { $0.value(forHTTPHeaderField: "Authorization") == "Bearer renewed" }.count == 8)
        #expect(requests.allSatisfy { $0.httpBody == request.httpBody && $0.httpMethod == "POST"
            && $0.value(forHTTPHeaderField: "Idempotency-Key") == "stable-id" })
        #expect(await gate.calls == 1)
    }

    @Test func refresh500EndsAllEightAndLateRequestsDoNotRefreshAgain() async throws {
        let gate = Gate(); let server = Server()
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let client = try client(session, server); let request = request()
        let tasks = (0..<8).map { _ in Task { try await client.execute(request) } }
        try await waitUntil {
            let count = await session.waitingCount
            let calls = await gate.calls
            return count == 8 && calls == 1
        }
        await gate.finish(.failure(.server500))
        for task in tasks {
            await #expect(throws: AuthenticationError.refreshFailed) { try await task.value }
        }
        await #expect(throws: AuthenticationError.refreshFailed) { try await client.execute(request) }
        #expect(await gate.calls == 1)
        #expect(await server.requests.count == 8)
    }

    @Test func delayed401UsesAlreadyRenewedLease() async throws {
        let gate = Gate()
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let old = try await session.current()
        await gate.finish(.success("renewed"))
        let first = try await session.refreshed(after: old)
        let delayed = try await session.refreshed(after: old)
        #expect(first.version == delayed.version)
        #expect(await gate.calls == 1)
    }

    @Test func cancellingOneWaiterDoesNotCancelOtherRequests() async throws {
        let gate = Gate()
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let old = try await session.current()
        let cancelled = Task { try await session.refreshed(after: old) }
        let survivor = Task { try await session.refreshed(after: old) }
        try await waitUntil { await session.waitingCount == 2 }
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await session.waitingCount == 1)
        await gate.finish(.success("renewed"))
        _ = try await survivor.value
        #expect(await gate.calls == 1)
    }

    @Test func logoutEndsWaitersAndRejectsLateRefresh() async throws {
        let gate = Gate()
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let old = try await session.current()
        let task = Task { try await session.refreshed(after: old) }
        try await waitUntil { await session.waitingCount == 1 }
        await session.invalidate()
        await #expect(throws: AuthenticationError.invalidated) { try await task.value }
        await gate.finish(.success("renewed"))
        await #expect(throws: AuthenticationError.invalidated) { try await session.current() }
    }

    @Test func deadlineEndsWaitersEvenWhenRefreshIgnoresCancellation() async throws {
        let refresh = Gate(); let deadline = Gate()
        let session = try AuthenticationSession(token: "expired", refresh: { try await refresh.wait() },
            deadline: { _ = try await deadline.wait() })
        let old = try await session.current()
        let task = Task { try await session.refreshed(after: old) }
        try await waitUntil { await session.waitingCount == 1 }
        await deadline.finish(.success("fire"))
        await #expect(throws: AuthenticationError.refreshTimedOut) { try await task.value }
        await refresh.finish(.success("too-late"))
        await #expect(throws: AuthenticationError.refreshTimedOut) { try await session.current() }
    }

    @Test func second401StopsAfterOneReplay() async throws {
        let gate = Gate(); await gate.finish(.success("renewed"))
        let server = Server(always401: true)
        let session = try AuthenticationSession(token: "expired", refresh: { try await gate.wait() })
        let client = try client(session, server)
        await #expect(throws: AuthenticationError.unauthorized) { try await client.execute(request()) }
        #expect(await server.requests.count == 2)
        #expect(await gate.calls == 1)
    }

    @Test func logoutRejectsResponseAlreadyInFlight() async throws {
        let gate = Gate()
        let session = try AuthenticationSession(token: "valid", refresh: { "renewed" })
        let client = try AuthenticatedHTTPClient(origin: URL(string: "https://auth.example.invalid")!,
            session: session, transport: { request in
                _ = try await gate.wait()
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
        let request = request()
        let task = Task { try await client.execute(request) }
        try await waitUntil { await gate.calls == 1 }
        await session.invalidate()
        await gate.finish(.success("release"))
        await #expect(throws: AuthenticationError.invalidated) { try await task.value }
    }

    @Test func refusesForeignOriginsAndInvalidCredentials() async throws {
        #expect(throws: AuthenticationError.invalidCredential) {
            try AuthenticationSession(token: "bad\r\nheader", refresh: { "renewed" })
        }
        let server = Server()
        let session = try AuthenticationSession(token: "expired", refresh: { "renewed" })
        let client = try client(session, server)
        for url in ["http://auth.example.invalid", "https://other.example.invalid", "https://auth.example.invalid:444"] {
            let request = URLRequest(url: URL(string: url)!)
            await #expect(throws: AuthenticationError.invalidOrigin) { try await client.execute(request) }
        }
        #expect(await server.requests.isEmpty)
    }
}
