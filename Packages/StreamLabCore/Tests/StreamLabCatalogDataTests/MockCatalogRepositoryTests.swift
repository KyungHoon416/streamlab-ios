import Foundation
import Testing
import StreamLabDomain
@testable import StreamLabCatalogData

@Suite("StreamLab Phase 1 Catalog")
struct MockCatalogRepositoryTests {
    let adult = ViewerProfile.demo[0]
    let otherAdult = ViewerProfile.demo[1]
    let kids = ViewerProfile.demo[2]

    @Test func fixtureHasExactly2000Items() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        #expect(try await repository.fixtureCount() == 2_000)
    }

    @Test func homeHasFiveRailsWithUniqueIdsPerRail() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let snapshot = try await repository.home(profile: adult)
        #expect(snapshot.rails.count == 5)
        for rail in snapshot.rails {
            #expect(!rail.items.isEmpty)
            #expect(Set(rail.items.map(\.id)).count == rail.items.count)
        }
    }

    @Test func cursorPagesNeverRepeatItems() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        var cursor: String?
        var fetched: [String] = []
        repeat {
            let page = try await repository.browse(profile: adult, after: cursor, limit: 33)
            fetched += page.items.map(\.id)
            cursor = page.nextCursor
        } while cursor != nil
        #expect(fetched.count == 2_000)
        #expect(Set(fetched).count == fetched.count)
    }

    @Test func kidsNeverSeeAdultTitlesEvenByDirectId() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let adultPage = try await repository.browse(profile: adult, after: nil, limit: 100)
        let restricted = try #require(adultPage.items.first(where: { !$0.rating.kidsAllowed }))
        #expect(try await repository.detail(id: restricted.id, profile: kids) == nil)
        let kidsPage = try await repository.browse(profile: kids, after: nil, limit: 100)
        #expect(kidsPage.items.allSatisfy { $0.rating.kidsAllowed })
    }

    @Test func profileProgressIsIsolated() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let first = try await repository.home(profile: adult)
        let second = try await repository.home(profile: otherAdult)
        let child = try await repository.home(profile: kids)
        #expect(first.continueWatching.count == 3)
        #expect(second.continueWatching.count == 2)
        #expect(child.continueWatching.count == 2)
        #expect(Set(first.continueWatching.map(\.id)).isDisjoint(with: Set(second.continueWatching.map(\.id))))
    }

    @Test func searchIsPageableAndRespectsProfileRestrictions() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let page = try await repository.search("모험", profile: kids, after: nil, limit: 12)
        #expect(page.items.count <= 12)
        #expect(page.items.allSatisfy { $0.rating.kidsAllowed })
    }

    @Test func invalidCursorAndLimitFailClearly() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        await #expect(throws: CatalogFailure.invalidCursor) {
            try await repository.browse(profile: adult, after: "offset:-6", limit: 20)
        }
        await #expect(throws: CatalogFailure.invalidPageLimit) {
            try await repository.browse(profile: adult, after: nil, limit: 0)
        }
    }
}
