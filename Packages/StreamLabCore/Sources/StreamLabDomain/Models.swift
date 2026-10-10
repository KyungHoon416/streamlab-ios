import Foundation

public enum ProfileKind: String, Codable, Sendable, Hashable {
    case adult, kids
}

public struct ViewerProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let displayName: String
    public let kind: ProfileKind
    public let avatarSymbol: String

    public init(id: String, displayName: String, kind: ProfileKind, avatarSymbol: String) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.avatarSymbol = avatarSymbol
    }

    public static let demo: [Self] = [
        .init(id: "adult-a", displayName: "Alex", kind: .adult, avatarSymbol: "person.fill"),
        .init(id: "adult-b", displayName: "Jamie", kind: .adult, avatarSymbol: "person.crop.square.fill"),
        .init(id: "kids-a", displayName: "Kids", kind: .kids, avatarSymbol: "star.fill")
    ]
}

public enum ContentRating: String, Codable, Sendable, Hashable {
    case all = "ALL"
    case seven = "7+"
    case twelve = "12+"
    case fifteen = "15+"
    case nineteen = "19+"

    public var kidsAllowed: Bool { self == .all || self == .seven }
}

public enum MediaKind: String, Codable, Sendable, Hashable {
    case movie, series
}

public struct CatalogTitle: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let synopsis: String
    public let genre: String
    public let year: Int
    public let durationMinutes: Int
    public let kind: MediaKind
    public let rating: ContentRating
    public let visualSeed: Int
    public let popularity: Int

    public var typeLabel: String { kind == .movie ? "영화" : "시리즈" }

    public func canView(in profile: ViewerProfile) -> Bool {
        profile.kind != .kids || rating.kidsAllowed
    }
}

public struct ContinueWatchingItem: Identifiable, Sendable, Hashable {
    public let title: CatalogTitle
    public let positionSeconds: Int
    public let durationSeconds: Int
    public var id: String { title.id }
    public var fraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, Double(positionSeconds) / Double(durationSeconds)))
    }

    public init(title: CatalogTitle, positionSeconds: Int, durationSeconds: Int) {
        self.title = title
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
    }
}

public struct ContentRail: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let items: [CatalogTitle]

    public init(id: String, title: String, items: [CatalogTitle]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct HomeSnapshot: Sendable {
    public let hero: CatalogTitle
    public let rails: [ContentRail]
    public let continueWatching: [ContinueWatchingItem]

    public init(hero: CatalogTitle, rails: [ContentRail], continueWatching: [ContinueWatchingItem]) {
        self.hero = hero
        self.rails = rails
        self.continueWatching = continueWatching
    }
}

public struct CatalogPage: Sendable {
    public let items: [CatalogTitle]
    public let nextCursor: String?

    public init(items: [CatalogTitle], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public enum CatalogFailure: Error, Sendable, Equatable {
    case missingFixture
    case invalidCursor
    case emptyCatalog
    case invalidPageLimit
}

public protocol CatalogRepository: Sendable {
    func home(profile: ViewerProfile) async throws -> HomeSnapshot
    func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage
    func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage
    func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle?
}
