import Foundation
import Testing
@testable import StreamLabPresentation

@Suite("B3 HTTP authentication integration", .timeLimit(.minutes(1)), .enabled(if:
    ProcessInfo.processInfo.environment["STREAMLAB_AUTH_FIXTURE_URL"] != nil))
struct HTTPAuthenticationTests {
    private struct Token: Decodable { let accessToken: String }
    private struct Stats: Decodable {
        let refreshCalls: Int
        let rejected: Int
        let accepted: Int
        let fingerprints: [String]
        let ids: [String]
    }
    private struct Fixture: Sendable {
        let url: URL
        init() throws {
            let raw = try #require(ProcessInfo.processInfo.environment["STREAMLAB_AUTH_FIXTURE_URL"])
            let base = try #require(URL(string: raw))
            try #require(base.scheme == "http" && base.host == "127.0.0.1")
            url = base.appendingPathComponent("case").appendingPathComponent(UUID().uuidString)
        }
        func post(_ path: String, body: String = "{}") async throws -> (Data, HTTPURLResponse) {
            var request = URLRequest(url: url.appendingPathComponent(path), timeoutInterval: 12)
            request.httpMethod = "POST"; request.httpBody = Data(body.utf8)
            let (data, response) = try await HTTPMutationTransport.load(request)
            return (data, try #require(response as? HTTPURLResponse))
        }
        func command(_ path: String, body: String = "{}") async throws {
            let (_, response) = try await post(path, body: body)
            try #require(response.statusCode == 200)
        }
        func refresh() async throws -> String {
            let (data, response) = try await post("refresh")
            guard response.statusCode == 200 else {
                throw MutationHTTPError.status(response.statusCode, retryAfter: nil)
            }
            return try JSONDecoder().decode(Token.self, from: data).accessToken
        }
        func stats() async throws -> Stats {
            let (data, response) = try await post("stats")
            try #require(response.statusCode == 200)
            return try JSONDecoder().decode(Stats.self, from: data)
        }
    }

    private func run(success: Bool) async throws {
        let fixture = try Fixture()
        try await fixture.command("configure", body: success ? "{\"mode\":\"success\"}" : "{\"mode\":\"failure\"}")
        let session = try AuthenticationSession(token: "fixture-expired", refresh: { try await fixture.refresh() })
        let origin = URL(string: "https://auth.example.invalid")!
        let client = try AuthenticatedHTTPClient(origin: origin, session: session, transport: { request in
            // Only routing is injected. Actual headers, bodies and HTTP responses traverse URLSession.
            var routed = request
            routed.url = fixture.url.appendingPathComponent(try #require(request.url?.lastPathComponent))
            return try await HTTPMutationTransport.load(routed)
        })
        var request = URLRequest(url: origin.appendingPathComponent("resource"))
        request.httpMethod = "POST"; request.httpBody = Data("{\"payload\":42}".utf8)
        request.setValue("fixture-stable-id", forHTTPHeaderField: "Idempotency-Key")
        let immutable = request
        let tasks = (0..<8).map { _ in Task { try await client.execute(immutable) } }
        defer { tasks.forEach { $0.cancel() } }
        do {
            let clock = ContinuousClock(); let limit = clock.now.advanced(by: .seconds(5))
            while await session.waitingCount != 8 {
                guard clock.now < limit else {
                    Issue.record("Eight requests did not overlap at refresh barrier")
                    throw URLError(.timedOut)
                }
                try await Task.sleep(for: .milliseconds(1))
            }
            try await fixture.command("release")
            for task in tasks {
                if success {
                    let (_, response) = try await task.value
                    #expect((response as? HTTPURLResponse)?.statusCode == 200)
                } else {
                    await #expect(throws: AuthenticationError.refreshFailed) { try await task.value }
                }
            }
            if !success {
                await #expect(throws: AuthenticationError.refreshFailed) { try await client.execute(immutable) }
            }
            let stats = try await fixture.stats()
            #expect(stats.refreshCalls == 1)
            #expect(stats.rejected == 8)
            #expect(stats.accepted == (success ? 8 : 0))
            #expect(stats.fingerprints.count == (success ? 16 : 8))
            #expect(Set(stats.fingerprints).count == 1)
            #expect(Set(stats.ids) == ["fixture-stable-id"])
            await session.invalidate()
        } catch {
            await session.invalidate()
            throw error
        }
    }

    @Test func eightHTTP401sShareOneSuccessfulRefresh() async throws {
        try await run(success: true)
        print("HTTP AUTH PASS success")
    }

    @Test func refreshHTTP500TerminatesAllEightWithoutRefreshStorm() async throws {
        try await run(success: false)
        print("HTTP AUTH PASS failure")
    }

    @Test func logoutRejectsSuccessfulHTTPResponseAlreadyInFlight() async throws {
        let fixture = try Fixture()
        try await fixture.command("configure", body: "{\"mode\":\"delayed-resource\"}")
        let session = try AuthenticationSession(token: "fixture-valid", refresh: { try await fixture.refresh() })
        let origin = URL(string: "https://auth.example.invalid")!
        let client = try AuthenticatedHTTPClient(origin: origin, session: session, transport: { request in
            var routed = request
            routed.url = fixture.url.appendingPathComponent("resource")
            return try await HTTPMutationTransport.load(routed)
        })
        var request = URLRequest(url: origin.appendingPathComponent("resource"))
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        let immutable = request
        let task = Task { try await client.execute(immutable) }
        defer { task.cancel() }
        do {
            let clock = ContinuousClock()
            let limit = clock.now.advanced(by: .seconds(5))
            while try await fixture.stats().accepted != 1 {
                guard clock.now < limit else { throw URLError(.timedOut) }
                try await Task.sleep(for: .milliseconds(5))
            }
            // The server has received the request but cannot reply until logout finishes.
            await session.invalidate()
            try await fixture.command("release")
            await #expect(throws: AuthenticationError.invalidated) { try await task.value }
            await #expect(throws: AuthenticationError.invalidated) { try await client.execute(immutable) }
            let stats = try await fixture.stats()
            #expect(stats.accepted == 1)
            #expect(stats.refreshCalls == 0)
            print("HTTP AUTH PASS logout-in-flight")
        } catch {
            await session.invalidate()
            try? await fixture.command("release")
            throw error
        }
    }

}
