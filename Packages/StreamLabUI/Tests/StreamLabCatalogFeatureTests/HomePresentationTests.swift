import Combine
import Foundation
import StreamLabDomain
import StreamLabCatalogData
import Testing
@testable import StreamLabCatalogFeature

@MainActor struct HomePresentationTests {
    private actor Repository: CatalogRepository {
        let base = MockCatalogRepository(responseDelay: .zero)
        var failNext: Bool
        init(failNext: Bool = false) { self.failNext = failNext }
        func home(profile: ViewerProfile) async throws -> HomeSnapshot {
            if failNext { failNext = false; throw URLError(.notConnectedToInternet) }
            return try await base.home(profile: profile)
        }
        func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
            try await base.browse(profile: profile, after: cursor, limit: limit)
        }
        func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
            try await base.search(query, profile: profile, after: cursor, limit: limit)
        }
        func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? {
            try await base.detail(id: id, profile: profile)
        }
    }
    private func waitForRequest(_ model: CatalogScreenModel) async throws {
        for _ in 0..<1000 {
            if !model.store.loading { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Home request did not finish")
    }

    @Test func firstLoadPublishesContentOnceAndUnchangedLifecycleDoesNotRepublish() async throws {
        let name = "home-presentation-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let session = CatalogSession(profile: ViewerProfile.demo[0], repository: Repository(), configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let model = CatalogScreenModel(session: session, screen: .home)
        var publications = 0
        let observer = model.objectWillChange.sink { publications += 1 }
        defer { observer.cancel() }
        model.appear(phase: .active)
        #expect(model.store.loading)
        #expect(publications == 0) // Same loading UI as the initial view.
        try await waitForRequest(model)
        #expect(model.store.home != nil)
        #expect(publications == 1)
        model.setPhase(.inactive)
        model.setPhase(.active)
        model.disappear()
        model.appear(phase: .active)
        #expect(publications == 1)
        // Clearing loaded content must still reach the screen.
        model.store.invalidate()
        #expect(publications == 2)
        #expect(model.store.home == nil)
    }

    @Test func failureRetryAndSuccessEachPublishVisibleChange() async throws {
        let name = "home-retry-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let session = CatalogSession(profile: ViewerProfile.demo[0], repository: Repository(failNext: true), configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let model = CatalogScreenModel(session: session, screen: .home)
        var publications = 0
        let observer = model.objectWillChange.sink { publications += 1 }
        defer { observer.cancel() }
        model.appear(phase: .active)
        try await waitForRequest(model)
        #expect(model.store.errorMessage != nil)
        #expect(publications == 1)
        model.retry()
        #expect(model.store.errorMessage == nil)
        #expect(model.store.loading)
        #expect(publications == 2)
        try await waitForRequest(model)
        #expect(model.store.home != nil)
        #expect(publications == 3)
    }
}
