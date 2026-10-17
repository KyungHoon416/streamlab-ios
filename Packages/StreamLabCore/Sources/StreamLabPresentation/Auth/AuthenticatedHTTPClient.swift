import Foundation

/// Opt-in execute function for HTTPMutationTransport. A 401 can replay a request once.
/// Refresh must use a separate unauthenticated transport, never recursively call this client.
public struct AuthenticatedHTTPClient: Sendable {
    private let origin: URL
    private let session: AuthenticationSession
    private let transport: HTTPMutationTransport.Execute

    public init(origin: URL, session: AuthenticationSession,
                transport: @escaping HTTPMutationTransport.Execute = { try await HTTPMutationTransport.load($0) }) throws {
        guard origin.scheme?.lowercased() == "https", origin.host?.isEmpty == false,
              origin.user == nil, origin.password == nil, origin.query == nil, origin.fragment == nil else {
            throw AuthenticationError.invalidOrigin
        }
        self.origin = origin; self.session = session; self.transport = transport
    }

    public func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url, url.scheme?.lowercased() == "https",
              url.host?.lowercased() == origin.host?.lowercased(), (url.port ?? 443) == (origin.port ?? 443),
              url.user == nil, url.password == nil, url.fragment == nil, request.httpBodyStream == nil else {
            throw AuthenticationError.invalidOrigin
        }
        let initial = try await session.current()
        let first = try await send(request, lease: initial)
        guard (first.1 as? HTTPURLResponse)?.statusCode == 401 else { return first }
        let renewed = try await session.refreshed(after: initial)
        let second = try await send(request, lease: renewed)
        if (second.1 as? HTTPURLResponse)?.statusCode == 401 {
            await session.reject(renewed)
            throw AuthenticationError.unauthorized
        }
        return second
    }

    private func send(_ request: URLRequest, lease: AuthenticationSession.Lease) async throws -> (Data, URLResponse) {
        try await session.checkActive()
        var authorized = request
        authorized.setValue("Bearer \(lease.token)", forHTTPHeaderField: "Authorization")
        let response = try await transport(authorized)
        try await session.checkActive()
        return response
    }
}
