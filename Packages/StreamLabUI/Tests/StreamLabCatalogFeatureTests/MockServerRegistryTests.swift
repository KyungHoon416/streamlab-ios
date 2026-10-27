import Combine
import Foundation
import StreamLabDomain
import StreamLabCatalogData
import Testing
@testable import StreamLabCatalogFeature

@Suite("Mock server file ownership")
struct MockServerRegistryTests {
    @Test func concurrentRequestsShareOneOwnerAndSeparateDomains() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = MockServerRegistry()
        let url = root.appendingPathComponent("progress.json")
        async let first = registry.server(at: url)
        async let second = registry.server(at: url)
        let (a, b) = try await (first, second)
        #expect(a === b)
        let other = try await registry.server(at: root.appendingPathComponent("search.json"))
        #expect(a !== other)
    }

    @Test func corruptFileIsPreservedAndFailureIsNotCached() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: url)
        let registry = MockServerRegistry()
        do {
            _ = try await registry.server(at: url)
            Issue.record("Corrupt server state must not silently reset")
        } catch { }
        #expect(try Data(contentsOf: url) == corrupt)
        try FileManager.default.removeItem(at: url)
        _ = try await registry.server(at: url)
    }
    @Test @MainActor func unchangedRefreshDoesNotRepublishButToggleDoes() async throws {
        let name = "list-publishing-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let store = MyListStore(profile: ViewerProfile.demo[0], defaults: defaults, accountID: name)
        defer { store.invalidate(); defaults.removePersistentDomain(forName: name) }
        await store.waitForSync()
        var publications = 0
        let observer = store.$items.dropFirst().sink { _ in publications += 1 }
        defer { observer.cancel() }
        store.refresh()
        await store.waitForSync()
        #expect(publications == 0)
        let repository = MockCatalogRepository(responseDelay: .zero)
        let title = try await repository.home(profile: ViewerProfile.demo[0]).hero
        store.toggle(title)
        #expect(store.contains(title))
        #expect(publications == 1)
        await store.waitForSync()
        store.refresh()
        await store.waitForSync()
        #expect(publications == 1)
    }

}
