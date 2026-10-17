import Foundation
import Testing
import StreamLabPresentation

/// Enabled by check-http-loader-mac.sh, which owns a loopback fixture process.
@Suite("B2 URLSession loader integration", .enabled(if:
    ProcessInfo.processInfo.environment["STREAMLAB_HTTP_FIXTURE_URL"] != nil))
struct HTTPMutationLoaderTests {
    private struct Stats: Decodable {
        let targetHits: Int
        let slowStarted: Bool
        let slowDisconnected: Bool
    }

    private func request(_ path: String) throws -> URLRequest {
        let raw = try #require(ProcessInfo.processInfo.environment["STREAMLAB_HTTP_FIXTURE_URL"])
        let base = try #require(URL(string: raw))
        // Plain HTTP is restricted to this local test fixture. The adapter still requires HTTPS.
        try #require(base.scheme == "http" && base.host == "127.0.0.1")
        return URLRequest(url: base.appendingPathComponent(path),
                          cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
    }

    private func stats() async throws -> Stats {
        let (data, _) = try await HTTPMutationTransport.load(request("stats"))
        return try JSONDecoder().decode(Stats.self, from: data)
    }

    private func waitFor(_ predicate: (Stats) -> Bool) async throws {
        for _ in 0..<100 {
            if predicate(try await stats()) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Loopback fixture did not reach expected state within polling budget")
        throw URLError(.timedOut)
    }

    @Test func redirectIsReturnedWithoutFollowingLocation() async throws {
        let (data, response) = try await HTTPMutationTransport.load(request("redirect"))
        #expect((response as? HTTPURLResponse)?.statusCode == 302)
        #expect(data == Data("redirect".utf8))
        #expect(try await stats().targetHits == 0)
        print("HTTP LOADER PASS redirect")
    }

    @Test func chunkedResponseAcceptsExactLimitAndRejectsOneExtraByte() async throws {
        let (data, response) = try await HTTPMutationTransport.load(request("exact"))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data.count == 4 * 1024 * 1024)
        #expect(data.allSatisfy { $0 == 120 })
        await #expect(throws: MutationWireError.oversizedResponse) {
            try await HTTPMutationTransport.load(request("oversized"))
        }
        print("HTTP LOADER PASS streaming-limit")
    }

    @Test func cancellationWhileStreamingClosesConnection() async throws {
        let slowRequest = try request("slow")
        let task = Task { try await HTTPMutationTransport.load(slowRequest) }
        defer { task.cancel() }
        try await waitFor { $0.slowStarted }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled stream must not return a successful body")
        } catch is CancellationError {
            // Explicit cancellation check in the loader.
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        }
        try await waitFor { $0.slowDisconnected }
        print("HTTP LOADER PASS cancellation")
    }
}
