import Foundation
import StreamLabDomain

public enum MutationWireError: Error, Equatable {
    case invalidEndpoint, nonHTTPResponse, invalidPayload, oversizedResponse, invalidRetryAfter
}

/// Opt-in transport for the draft contract in Docs/MUTATION_HTTP_CONTRACT.md.
/// The app stays on Mock until an authenticated backend is configured.
public struct HTTPMutationTransport: MutationTransport, MutationSnapshotSource {
    public typealias Execute = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let baseURL: URL
    private let execute: Execute
    private let now: @Sendable () -> Date
    private struct Receipt: Decodable { let id: UUID; let revision: UInt64 }
    private struct Conflict: Decodable { let currentRevision: UInt64 }
    private struct Snapshot: Decodable {
        let scope: MutationScope
        let revision: UInt64
        let values: [String: Data]
        let myListItemRevisions: [String: UInt64]?
        let myListRevisionFloor: UInt64?
    }

    public init(baseURL: URL, execute: @escaping Execute = { try await HTTPMutationTransport.load($0) },
                now: @escaping @Sendable () -> Date = { Date() }) throws {
        guard baseURL.scheme?.lowercased() == "https", baseURL.host?.isEmpty == false,
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else {
            throw MutationWireError.invalidEndpoint
        }
        self.baseURL = baseURL; self.execute = execute; self.now = now
    }

    public func send(_ mutation: DurableMutation) async throws -> UInt64 {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var request = makeRequest("mutations")
        request.httpBody = try encoder.encode(mutation)
        request.setValue(mutation.id.uuidString, forHTTPHeaderField: "Idempotency-Key")
        let (data, response) = try await perform(request)
        if response.statusCode == 409 {
            guard let conflict = try? JSONDecoder().decode(Conflict.self, from: data),
                  conflict.currentRevision >= mutation.baseRevision else { throw MutationWireError.invalidPayload }
            throw MutationQueueError.conflict(currentRevision: conflict.currentRevision)
        }
        try checkStatus(response)
        guard let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
              receipt.id == mutation.id, mutation.baseRevision < UInt64.max,
              receipt.revision == mutation.baseRevision + 1 else { throw MutationQueueError.invalidReceipt }
        return receipt.revision
    }

    public func snapshot(for scope: MutationScope) async throws -> MutationSnapshot {
        var request = makeRequest("snapshot")
        request.httpBody = try JSONEncoder().encode(scope)
        let (data, response) = try await perform(request)
        try checkStatus(response)
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), snapshot.scope == scope,
              (snapshot.myListRevisionFloor ?? 0) <= snapshot.revision,
              snapshot.myListItemRevisions?.values.allSatisfy({ $0 <= snapshot.revision }) ?? true else {
            throw MutationWireError.invalidPayload
        }
        return MutationSnapshot(scope: scope, revision: snapshot.revision, values: snapshot.values,
                                myListItemRevisions: snapshot.myListItemRevisions,
                                myListRevisionFloor: snapshot.myListRevisionFloor ?? snapshot.revision)
    }

    private func makeRequest(_ path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let (data, response) = try await execute(request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw MutationWireError.nonHTTPResponse }
        guard data.count <= 4 * 1024 * 1024 else { throw MutationWireError.oversizedResponse }
        return (data, http)
    }

    private func checkStatus(_ response: HTTPURLResponse) throws {
        guard response.statusCode != 200 else { return }
        let delay: TimeInterval?
        if response.statusCode == 429 || response.statusCode == 503 {
            delay = try Self.retryAfter(response.value(forHTTPHeaderField: "Retry-After"), now: now())
        } else { delay = nil }
        throw MutationHTTPError.status(response.statusCode, retryAfter: delay)
    }

    /// Seconds or canonical IMF-fixdate. Malformed present headers stop this attempt.
    public static func retryAfter(_ header: String?, now: Date) throws -> TimeInterval? {
        guard let header else { return nil }
        let text = header.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) {
            guard let seconds = Double(text), seconds.isFinite else { throw MutationWireError.invalidRetryAfter }
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.isLenient = false
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else {
            throw MutationWireError.invalidRetryAfter
        }
        return max(0, date.timeIntervalSince(now))
    }

    /// Isolated ephemeral session: no cookies/cache and no automatic redirects.
    public static func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 4 * 1024 * 1024 else { throw MutationWireError.oversizedResponse }
            data.append(byte)
        }
        return (data, response)
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
