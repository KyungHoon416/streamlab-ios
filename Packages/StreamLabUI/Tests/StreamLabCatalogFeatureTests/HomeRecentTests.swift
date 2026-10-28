import Combine
import Foundation
import StreamLabDomain
import StreamLabCatalogData
import Testing
@testable import StreamLabCatalogFeature

struct HomeRecentTests {
    actor Gate {
        private var opened = false
        private var waiting: [String: CheckedContinuation<Void, Never>] = [:]
        private(set) var calls: [String] = []
        private(set) var maximum = 0
        func enter(_ id: String) async {
            calls.append(id)
            guard !opened else { return }
            await withCheckedContinuation { continuation in
                waiting[id] = continuation
                maximum = max(maximum, waiting.count)
            }
        }
        func count() -> Int { waiting.count }
        func release() { opened = true; let old = waiting; waiting = [:]; for value in old.values { value.resume() } }
    }

    @Test func boundedLookupsDeduplicateAndStopEnqueuingOnCancellation() async throws {
        let gate = Gate()
        let task = Task {
            await RecentTitleResolver.resolve(ids: ["a", "b", "c", "d", "e", "a"]) { id in
                await gate.enter(id)
                return nil
            }
        }
        for _ in 0..<1000 {
            if await gate.count() == 4 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await gate.count() == 4)
        task.cancel()
        await gate.release()
        let result = await task.value
        #expect(await gate.maximum == 4)
        #expect(Set(await gate.calls) == Set(["a", "b", "c", "d"]))
        #expect(result.titles.isEmpty)
    }

    @Test func partialFailureKeepsSuccessfulAuthorizedLookupResults() async throws {
        let repository = MockCatalogRepository(responseDelay: .zero)
        let title = try await repository.home(profile: ViewerProfile.demo[0]).hero
        let result = await RecentTitleResolver.resolve(ids: [title.id, "failure", "missing", title.id]) { id in
            if id == "failure" { throw URLError(.timedOut) }
            return id == title.id ? title : nil
        }
        #expect(result.failed)
        #expect(result.titles == [title.id: title])
    }

    @Test @MainActor func unchangedSnapshotDoesNotRepublishAndProfilesStaySeparate() async throws {
        let name = "recent-tests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let a = CatalogSession(profile: ViewerProfile.demo[0], repository: repository, configuration: (name, defaults))
        let b = CatalogSession(profile: ViewerProfile.demo[1], repository: repository, configuration: (name, defaults))
        defer { a.invalidate(); b.invalidate(); defaults.removePersistentDomain(forName: name) }
        let title = try await repository.home(profile: a.profile).hero
        a.progress.save(titleID: title.id, sourceID: "apple-bipbop-v1", position: 15, duration: 120)
        let model = HomeRecentModel(session: a)
        var publications = 0
        let observer = model.$snapshot.dropFirst().sink { _ in publications += 1 }
        defer { observer.cancel() }
        await model.refresh()
        #expect(model.snapshot.items.map(\.id) == [title.id])
        #expect(model.snapshot.items.first?.source == .hls)
        await model.refresh()
        #expect(publications == 1)
        let other = HomeRecentModel(session: b)
        await other.refresh()
        #expect(other.snapshot.items.isEmpty)
        a.progress.save(titleID: title.id, sourceID: "apple-bipbop-v1", position: 25, duration: 120)
        await model.refresh()
        #expect(model.snapshot.items.first?.entry.position == 25)
        #expect(publications == 2)
        a.invalidate()
        await model.refresh()
        #expect(publications == 2)
    }
    private struct DelayedRepository: CatalogRepository {
        let base: MockCatalogRepository
        let gate: Gate
        func home(profile: ViewerProfile) async throws -> HomeSnapshot { try await base.home(profile: profile) }
        func browse(profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
            try await base.browse(profile: profile, after: cursor, limit: limit)
        }
        func search(_ query: String, profile: ViewerProfile, after cursor: String?, limit: Int) async throws -> CatalogPage {
            try await base.search(query, profile: profile, after: cursor, limit: limit)
        }
        func detail(id: String, profile: ViewerProfile) async throws -> CatalogTitle? {
            let value = try await base.detail(id: id, profile: profile)
            await gate.enter(id) // Deliberately ignores cancellation after loading.
            return value
        }
    }

    @Test @MainActor func lateResultAfterSessionInvalidationDoesNotPublish() async throws {
        let name = "recent-invalidation-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let base = MockCatalogRepository(responseDelay: .zero)
        let gate = Gate()
        let session = CatalogSession(profile: ViewerProfile.demo[0],
                                     repository: DelayedRepository(base: base, gate: gate),
                                     configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let title = try await base.home(profile: session.profile).hero
        session.progress.save(titleID: title.id, sourceID: "bundled-demo-v1", position: 15, duration: 30)
        let model = HomeRecentModel(session: session)
        let task = Task { await model.refresh() }
        for _ in 0..<1000 {
            if await gate.count() == 1 { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await gate.count() == 1)
        session.invalidate()
        await gate.release()
        await task.value
        #expect(model.snapshot.items.isEmpty)
    }

}
