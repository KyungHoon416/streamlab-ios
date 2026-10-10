import Foundation
import StreamLabDomain

/// No network, user data, API keys, or licensed commercial media are used.
/// Actors protect cached fixtures from concurrent callers.
public actor MockCatalogRepository: CatalogRepository {
    private var cachedTitles: [CatalogTitle]?
    private let responseDelay: Duration

    public init(responseDelay: Duration = .milliseconds(120)) {
        self.responseDelay = responseDelay
    }

    private func allTitles() throws -> [CatalogTitle] {
        if let cachedTitles { return cachedTitles }
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogFailure.missingFixture
        }
        let titles = try JSONDecoder().decode([CatalogTitle].self, from: Data(contentsOf: url))
        cachedTitles = titles
        return titles
    }

    private func loadFor(_ profile: ViewerProfile) throws -> [CatalogTitle] {
        try allTitles().filter { $0.canView(in: profile) }
    }

    private func simulateRequest() async throws {
        try Task.checkCancellation()
        try await Task.sleep(for: responseDelay)
        try Task.checkCancellation()
    }

    public func fixtureCount() throws -> Int { try allTitles().count }

    public func home(profile: ViewerProfile) async throws -> HomeSnapshot {
        try await simulateRequest()
        let titles = try loadFor(profile)
        guard let hero = titles.first else { throw CatalogFailure.emptyCatalog }
        let definitions: [(String, String, (CatalogTitle) -> Bool)] = [
            ("trending", "지금 인기", { _ in true }),
            ("series", "인기 시리즈", { $0.kind == .series }),
            ("action", "액션 · 스릴러", { $0.genre == "액션" || $0.genre == "스릴러" }),
            ("family", "함께 보기 좋은", { $0.rating.kidsAllowed }),
            ("new", "새로 공개된 작품", { $0.year >= 2023 })
        ]
        let rails = definitions.map { id, label, predicate in
            ContentRail(id: id, title: label, items: Array(titles.filter(predicate).prefix(18)))
        }

        // Progress is purposely partitioned by exact profile id.
        let progressSeeds: [String: [(Int, Int)]] = [
            "adult-a": [(0, 740), (2, 1280), (4, 420)],
            "adult-b": [(5, 300), (7, 820)],
            "kids-a": [(0, 240), (3, 550)]
        ]
        let continueWatching = (progressSeeds[profile.id] ?? []).compactMap { index, seconds -> ContinueWatchingItem? in
            guard titles.indices.contains(index) else { return nil }
            return ContinueWatchingItem(
                title: titles[index],
                positionSeconds: seconds,
                durationSeconds: titles[index].durationMinutes * 60
            )
        }
        try Task.checkCancellation()
        return HomeSnapshot(hero: hero, rails: rails, continueWatching: continueWatching)
    }

    public func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        try await simulateRequest()
        return try paginate(loadFor(profile), after: cursor, limit: limit)
    }

    public func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        try await simulateRequest()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let eligible = try loadFor(profile)
        let matching = text.isEmpty ? eligible : eligible.filter {
            $0.name.localizedStandardContains(text) ||
            $0.genre.localizedStandardContains(text) ||
            $0.synopsis.localizedStandardContains(text)
        }
        try Task.checkCancellation()
        return try paginate(matching, after: cursor, limit: limit)
    }

    public func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? {
        try await simulateRequest()
        let item = try allTitles().first { $0.id == id }
        guard let item, item.canView(in: profile) else { return nil }
        return item
    }

    private func paginate(_ titles: [CatalogTitle], after cursor: String?, limit: Int) throws -> CatalogPage {
        guard (1...100).contains(limit) else { throw CatalogFailure.invalidPageLimit }
        let offset: Int
        if let cursor {
            guard cursor.hasPrefix("offset:"),
                  let value = Int(cursor.dropFirst("offset:".count)),
                  value >= 0, value <= titles.count else {
                throw CatalogFailure.invalidCursor
            }
            offset = value
        } else {
            offset = 0
        }
        let end = min(offset + limit, titles.count)
        return CatalogPage(
            items: Array(titles[offset..<end]),
            nextCursor: end < titles.count ? "offset:\(end)" : nil
        )
    }
}
