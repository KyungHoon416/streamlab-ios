import Foundation
import StreamLabCatalogData

/// Disk reads and JSON decoding must not occupy the UI executor on first sync.
/// No suspension while creating a server: concurrent sessions share one file owner.
actor MockServerRegistry {
    static let shared = MockServerRegistry()
    private var servers: [URL: MockMutationServer] = [:]

    func server(at url: URL) throws -> MockMutationServer {
        if let server = servers[url] { return server }
        let server = try MockMutationServer(storageURL: url)
        servers[url] = server
        return server
    }
}
