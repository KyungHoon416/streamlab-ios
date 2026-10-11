import Foundation
import Testing
import StreamLabDomain
import StreamLabCatalogData
@testable import StreamLabPresentation

/// Continuation-controlled transport deliberately ignores cancellation.
/// No sleeps or polling: the test decides when every response arrives.
private actor ControlledRepository: CatalogRepository {
    private var pages: [String: CheckedContinuation<CatalogPage, any Error>] = [:]
    private var homes: [String: CheckedContinuation<HomeSnapshot, any Error>] = [:]
    private var details: [String: CheckedContinuation<CatalogTitle?, any Error>] = [:]
    private var started: Set<String> = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    func wait(_ key: String) async {
        if started.contains(key) { return }
        await withCheckedContinuation { waiters[key, default: []].append($0) }
    }
    private func signal(_ key: String) {
        started.insert(key)
        waiters.removeValue(forKey: key)?.forEach { $0.resume() }
    }
    func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        let key = "\(profile.id)/\(query)/\(cursor ?? "first")"
        return try await withCheckedThrowingContinuation { continuation in
            pages[key] = continuation
            signal(key)
        }
    }
    func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
        try await search("", profile: profile, after: cursor, limit: limit)
    }
    func home(profile: ViewerProfile) async throws -> HomeSnapshot {
        let key = "home/\(profile.id)"
        return try await withCheckedThrowingContinuation { continuation in
            homes[key] = continuation
            signal(key)
        }
    }
    func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? {
        let key = "detail/\(id)"
        return try await withCheckedThrowingContinuation { continuation in
            details[key] = continuation
            signal(key)
        }
    }
    func finish(_ key: String, page: CatalogPage) { pages.removeValue(forKey: key)!.resume(returning: page) }
    func finishHome(_ key: String, snapshot: HomeSnapshot) { homes.removeValue(forKey: key)!.resume(returning: snapshot) }
    func finishDetail(_ key: String, title: CatalogTitle?) { details.removeValue(forKey: key)!.resume(returning: title) }
    func fail(_ key: String) { pages.removeValue(forKey: key)!.resume(throwing: CatalogFailure.invalidCursor) }
}

@Suite("Presentation race and lifecycle regression", .timeLimit(.minutes(1)))
@MainActor struct CatalogStoreTests {
    let adult = ViewerProfile.demo[0]
    let kids = ViewerProfile.demo[2]
    private func titles() async throws -> [CatalogTitle] {
        try await MockCatalogRepository(responseDelay: .zero).browse(profile: adult, after: nil, limit: 4).items
    }
    @Test func suspendedPaginationRetainsPagesAndRejectsLateCompletion() async throws {
        let titles = try await titles()
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let first = store.search("keep", debounce: .zero)
        await repository.wait("adult-a/keep/first")
        await repository.finish("adult-a/keep/first", page: .init(items: [titles[0]], nextCursor: "next"))
        await first.value
        let next = try #require(store.loadNext())
        await repository.wait("adult-a/keep/next")
        store.suspend()
        await repository.finish("adult-a/keep/next", page: .init(items: [titles[1]], nextCursor: nil))
        await next.value
        #expect(store.items == [titles[0]])
        #expect(store.query == "keep")
        #expect(store.nextCursor == "next")
        #expect(!store.loading)
        store.select(kids)
        #expect(store.items.isEmpty)
        #expect(store.resume() == nil)
    }

    @Test func resumePaginationContinuesWithoutResettingLoadedPages() async throws {
        let store = CatalogStore(profile: adult, repository: MockCatalogRepository(responseDelay: .zero))
        await store.search("", debounce: .zero).value
        let firstIDs = store.items.map(\.id)
        #expect(firstIDs.count == 24)
        let cancelled = try #require(store.loadNext())
        // No await between starting and suspending: work cannot finish first.
        store.suspend()
        await cancelled.value
        let resumed = try #require(store.resume())
        await resumed.value
        #expect(store.items.count == 48)
        #expect(Array(store.items.prefix(24).map(\.id)) == firstIDs)
        #expect(Set(store.items.map(\.id)).count == 48)
        store.suspend()
        #expect(store.resume() == nil)
    }

    @Test func reversedSearchResponseCannotOverwriteLatest() async throws {
        let titles = try await titles()
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let old = store.search("old", debounce: .zero)
        await repository.wait("adult-a/old/first")
        let new = store.search("new", debounce: .zero)
        await repository.wait("adult-a/new/first")
        await repository.finish("adult-a/new/first", page: .init(items: [titles[1]], nextCursor: nil))
        await new.value
        await repository.finish("adult-a/old/first", page: .init(items: [titles[0]], nextCursor: nil))
        await old.value
        #expect(store.items == [titles[1]])
        #expect(store.query == "new")
        #expect(!store.loading)
    }
    @Test func profileSwitchRejectsOldHomeAndClearsProgressImmediately() async throws {
        let fixture = MockCatalogRepository(responseDelay: .zero)
        let adultHome = try await fixture.home(profile: adult)
        let kidsHome = try await fixture.home(profile: kids)
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let old = store.loadHome()
        await repository.wait("home/adult-a")
        store.select(kids)
        #expect(store.home == nil)
        let new = store.loadHome()
        await repository.wait("home/kids-a")
        await repository.finishHome("home/kids-a", snapshot: kidsHome)
        await new.value
        await repository.finishHome("home/adult-a", snapshot: adultHome)
        await old.value
        #expect(store.profile == kids)
        #expect(store.home?.continueWatching == kidsHome.continueWatching)
        #expect(store.home?.rails.flatMap(\.items).allSatisfy { $0.rating.kidsAllowed } == true)
    }
    @Test func profileSwitchRejectsOldSearchCompletion() async throws {
        let titles = try await titles()
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let task = store.search("old", debounce: .zero)
        await repository.wait("adult-a/old/first")
        store.select(kids)
        await repository.finish("adult-a/old/first", page: .init(items: titles, nextCursor: "offset:4"))
        await task.value
        #expect(store.items.isEmpty)
        #expect(store.nextCursor == nil)
        #expect(!store.loading)
    }
    @Test func repeatedPageAndInPageDuplicatesAreRemoved() async throws {
        let titles = try await titles()
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let first = store.search("", debounce: .zero)
        await repository.wait("adult-a//first")
        await repository.finish("adult-a//first", page: .init(items: [titles[0], titles[0]], nextCursor: "next"))
        await first.value
        let next = try #require(store.loadNext())
        #expect(store.loadNext() == nil)
        await repository.wait("adult-a//next")
        await repository.finish("adult-a//next", page: .init(items: [titles[0], titles[1], titles[1]], nextCursor: "next"))
        await next.value
        #expect(store.items == [titles[0], titles[1]])
        #expect(store.nextCursor == nil)
        #expect(store.errorMessage != nil)
    }
    @Test func leavingDetailInvalidatesLateResult() async throws {
        let title = try await titles()[0]
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let task = store.loadDetail(id: title.id)
        await repository.wait("detail/\(title.id)")
        store.invalidate()
        await repository.finishDetail("detail/\(title.id)", title: title)
        await task.value
        #expect(store.detail == nil)
        #expect(!store.loading)
    }
    @Test func rapidEntryExitDoesNotRetainStore() async throws {
        let title = try await titles()[0]
        for index in 0..<20 {
            let repository = ControlledRepository()
            var store: CatalogStore? = CatalogStore(profile: adult, repository: repository)
            // A weak capture keeps this probe non-owning across compiler versions.
            let isStoreReleased = { [weak store] in store == nil }
            let work = store!.search("\(index)", debounce: .zero)
            await repository.wait("adult-a/\(index)/first")
            store!.invalidate()
            store = nil
            #expect(isStoreReleased())
            await repository.finish("adult-a/\(index)/first", page: .init(items: [title], nextCursor: nil))
            await work.value
        }
    }
    @Test func staleFailureCannotOverwriteCurrentSuccess() async throws {
        let titles = try await titles()
        let repository = ControlledRepository()
        let store = CatalogStore(profile: adult, repository: repository)
        let old = store.search("old", debounce: .zero)
        await repository.wait("adult-a/old/first")
        let new = store.search("new", debounce: .zero)
        await repository.wait("adult-a/new/first")
        await repository.finish("adult-a/new/first", page: .init(items: titles, nextCursor: nil))
        await new.value
        await repository.fail("adult-a/old/first")
        await old.value
        #expect(store.errorMessage == nil)
        #expect(store.items == titles)
    }
    @Test func kidsHomeAndEverySearchPageEnforceRatings() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let store = CatalogStore(profile: kids, repository: repository)
        await store.loadHome().value
        #expect(store.home?.hero.rating.kidsAllowed == true)
        await store.search("", debounce: .zero).value
        while let next = store.loadNext() { await next.value }
        #expect(!store.items.isEmpty)
        #expect(store.items.allSatisfy { $0.rating.kidsAllowed })
        #expect(Set(store.items.map(\.id)).count == store.items.count)
    }
}
