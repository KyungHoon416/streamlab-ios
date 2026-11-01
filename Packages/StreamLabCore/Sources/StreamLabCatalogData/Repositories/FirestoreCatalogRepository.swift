import Foundation
import StreamLabDomain

/// Public, published catalog only. Authentication and user mutations remain separate.
/// No offline cache: an unavailable server is not silently replaced with demo content.
public actor FirestoreCatalogRepository: CatalogRepository {
    public typealias Loader = @Sendable (URLRequest) async throws -> Data
    private let endpoint: URL
    private let loader: Loader
    public init(projectID: String, loader: Loader? = nil) {
        precondition(projectID.range(of: "^[a-z][a-z0-9-]{4,60}$", options: .regularExpression) != nil)
        endpoint = URL(string: "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents:runQuery")!
        self.loader = loader ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count <= 4_000_000 else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }
    private struct Value: Decodable { let stringValue: String?; let integerValue: String?; let booleanValue: Bool? }
    private struct Document: Decodable { let fields: [String: Value] }
    private struct Row: Decodable { let document: Document? }
    private func load(profile: ViewerProfile, id: String? = nil) async throws -> [CatalogTitle] {
        var filters: [[String: Any]] = [["fieldFilter": ["field": ["fieldPath": "published"], "op": "EQUAL", "value": ["booleanValue": true]]]]
        if let id { filters.append(["fieldFilter": ["field": ["fieldPath": "id"], "op": "EQUAL", "value": ["stringValue": id]]]) }
        let predicate: [String: Any]
        if filters.count == 1 { predicate = filters[0] }
        else { predicate = ["compositeFilter": ["op": "AND", "filters": filters]] }
        let query: [String: Any] = ["from": [["collectionId": "titles"]], "where": predicate, "limit": id == nil ? 201 : 2]
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["structuredQuery": query])
        try Task.checkCancellation()
        let data = try await loader(request)
        guard data.count <= 4_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        let rows = try JSONDecoder().decode([Row].self, from: data)
        var result: [CatalogTitle] = []
        for row in rows {
            guard let fields = row.document?.fields else { continue }
            guard fields["published"]?.booleanValue == true else { throw URLError(.cannotParseResponse) }
            var object: [String: Any] = [:]
            for key in ["id", "name", "synopsis", "genre", "kind", "rating"] {
                guard let value = fields[key]?.stringValue else { throw URLError(.cannotParseResponse) }
                object[key] = value
            }
            for key in ["year", "durationMinutes", "visualSeed", "popularity"] {
                guard let string = fields[key]?.integerValue, let value = Int(string) else { throw URLError(.cannotParseResponse) }
                object[key] = value
            }
            for key in ["artworkURL", "streamURL"] {
                if let value = fields[key]?.stringValue, !value.isEmpty {
                    guard let url = URL(string: value), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
                          key != "streamURL" || ["m3u8", "mp4"].contains(url.pathExtension) else { throw URLError(.unsupportedURL) }
                    object[key] = value
                }
            }
            let title = try JSONDecoder().decode(CatalogTitle.self, from: JSONSerialization.data(withJSONObject: object))
            guard title.streamURL != nil, title.durationMinutes > 0, title.durationMinutes <= 10000,
                  (0...1000000).contains(title.visualSeed), !title.name.isEmpty,
                  title.id.range(of: "^[a-z0-9][a-z0-9-]{0,63}$", options: .regularExpression) != nil else { throw URLError(.cannotParseResponse) }
            result.append(title)
        }
        guard result.count <= 200 else { throw URLError(.dataLengthExceedsMaximum) }
        guard Set(result.map(\.id)).count == result.count else { throw CatalogFailure.duplicateID }
        try Task.checkCancellation()
        return result.filter { $0.canView(in: profile) }.sorted { $0.popularity == $1.popularity ? $0.id < $1.id : $0.popularity > $1.popularity }
    }
    public func home(profile: ViewerProfile) async throws -> HomeSnapshot {
        let titles = try await load(profile: profile)
        guard let first = titles.first else { throw CatalogFailure.emptyCatalog }
        let rails = [ContentRail(id: "published", title: "공개된 작품", items: Array(titles.prefix(18))),
                     ContentRail(id: "movies", title: "영화", items: Array(titles.filter { $0.kind == .movie }.prefix(18))),
                     ContentRail(id: "series", title: "시리즈", items: Array(titles.filter { $0.kind == .series }.prefix(18)))]
        return HomeSnapshot(hero: first, rails: rails.filter { !$0.items.isEmpty }, continueWatching: [])
    }
    public func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        try page(try await load(profile: profile), cursor: cursor, limit: limit)
    }
    public func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try page(try await load(profile: profile).filter { q.isEmpty || $0.name.localizedStandardContains(q) || $0.genre.localizedStandardContains(q) || $0.synopsis.localizedStandardContains(q) }, cursor: cursor, limit: limit)
    }
    public func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? {
        try await load(profile: profile, id: id).first { $0.id == id }
    }
    private func page(_ titles: [CatalogTitle], cursor: String?, limit: Int) throws -> CatalogPage {
        guard (1...100).contains(limit) else { throw CatalogFailure.invalidPageLimit }
        let offset: Int
        if let cursor {
            guard cursor.hasPrefix("offset:"), let value = Int(cursor.dropFirst(7)), (0...titles.count).contains(value) else { throw CatalogFailure.invalidCursor }
            offset = value
        } else { offset = 0 }
        let end = min(titles.count, offset + limit)
        return CatalogPage(items: Array(titles[offset..<end]), nextCursor: end < titles.count ? "offset:\(end)" : nil)
    }
}
