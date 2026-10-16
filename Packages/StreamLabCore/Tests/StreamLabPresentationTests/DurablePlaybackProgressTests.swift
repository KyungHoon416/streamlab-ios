import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B1 durable playback progress")
@MainActor struct DurablePlaybackProgressTests {
    @MainActor private struct Fixture {
        let name = "durable-progress-\(UUID())"
        let directory: URL
        let defaults: UserDefaults
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            defaults = try #require(UserDefaults(suiteName: name))
        }
        func store(profile: String = "adult-a", account: String = "local-demo") -> PlaybackProgressStore {
            PlaybackProgressStore(profileID: profile, defaults: defaults, durable: true,
                                  directory: directory, accountID: account)
        }
        func clean() {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    @Test func offlineRelaunchRestoresPositionAndExactRequest() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "movie", sourceID: "hls", position: 1540, duration: 3600)
        let pending = store.pendingMutations
        #expect(pending.count == 1)
        do { try await store.flush(using: OfflineProgressTransport()); Issue.record("Offline send succeeded") }
        catch { #expect(error is OfflineProgressTransport.Failure) }
        store.invalidate()
        let reopened = f.store()
        #expect(reopened.position(titleID: "movie", sourceID: "hls", duration: 3600) == 1540)
        #expect(reopened.pendingMutations == pending)
        #expect(reopened.recent().first?.position == 1540)
        let server = MockMutationServer()
        try await reopened.flush(using: server)
        #expect(reopened.pendingMutations.isEmpty)
        #expect(await server.revision(for: MutationScope(accountID: "local-demo", profileID: "adult-a")) == 1)
    }

    @Test func completionAndRestartSurviveRelaunchAsTombstones() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "finished", sourceID: "hls", position: 10, duration: 100)
        store.save(titleID: "finished", sourceID: "hls", position: 99, duration: 100)
        store.save(titleID: "restart", sourceID: "hls", position: 40, duration: 100)
        store.save(titleID: "restart", sourceID: "hls", position: 0, duration: 100)
        #expect(store.pendingMutations.count == 4)
        #expect(store.pendingMutations[1].value == nil)
        #expect(store.pendingMutations[3].value == nil)
        store.invalidate()
        let reopened = f.store()
        #expect(reopened.recent().isEmpty)
        #expect(reopened.position(titleID: "restart", sourceID: "hls", duration: 100) == nil)
        let server = MockMutationServer()
        try await reopened.flush(using: server)
        #expect(await server.values(for: MutationScope(accountID: "local-demo", profileID: "adult-a")).isEmpty)
    }

    @Test func migrationRunsOnceAndDoesNotResurrectDeletedLegacyRecord() throws {
        let f = try Fixture()
        defer { f.clean() }
        let legacy = PlaybackProgressStore(profileID: "adult-a", defaults: f.defaults)
        legacy.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        #expect(f.store(account: "account-b").recent().isEmpty)
        let store = f.store()
        #expect(store.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
        #expect(store.pendingMutations.count == 1)
        store.save(titleID: "movie", sourceID: "hls", position: 0, duration: 100)
        store.invalidate()
        let reopened = f.store()
        #expect(reopened.recent().isEmpty)
        #expect(reopened.pendingMutations.count == 2)
        #expect(legacy.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
    }

    @Test func accountProfileTitleAndSourceRemainSeparate() throws {
        let f = try Fixture()
        defer { f.clean() }
        let a = f.store()
        a.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        #expect(f.store(profile: "kids").recent().isEmpty)
        #expect(f.store(account: "account-b").recent().isEmpty)
        #expect(a.position(titleID: "other", sourceID: "hls", duration: 100) == nil)
        #expect(a.position(titleID: "movie", sourceID: "mp4", duration: 100) == nil)
        #expect(a.pendingMutations.first?.scope == MutationScope(accountID: "local-demo", profileID: "adult-a"))
    }

    @Test func invalidNumbersDoNotQueueOrChangeSavedPosition() throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        let pending = store.pendingMutations
        for position in [Double.nan, .infinity, -1] {
            store.save(titleID: "movie", sourceID: "hls", position: position, duration: 100)
        }
        store.save(titleID: "movie", sourceID: "hls", position: 40, duration: .infinity)
        #expect(store.pendingMutations == pending)
        #expect(store.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
        #expect(store.position(titleID: "movie", sourceID: "hls", duration: 200) == nil)
    }

    @Test func failedPersistencePreservesLastCommittedPositionAndReportsError() throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        let pending = store.pendingMutations
        try FileManager.default.removeItem(at: f.directory)
        store.save(titleID: "movie", sourceID: "hls", position: 50, duration: 100)
        #expect(store.persistenceError != nil)
        #expect(store.pendingMutations == pending)
        #expect(store.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
    }

    @Test func invalidatedSessionCannotWriteAnotherCheckpoint() throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        store.invalidate()
        store.save(titleID: "movie", sourceID: "hls", position: 60, duration: 100)
        #expect(store.recent().isEmpty)
        let reopened = f.store()
        #expect(reopened.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
        #expect(reopened.pendingMutations.count == 1)
    }

    @Test func acknowledgedProgressStillResumesAfterReopening() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let store = f.store()
        store.save(titleID: "movie", sourceID: "hls", position: 30, duration: 100)
        let server = MockMutationServer()
        try await store.flush(using: server)
        store.invalidate()
        let reopened = f.store()
        #expect(reopened.pendingMutations.isEmpty)
        #expect(reopened.position(titleID: "movie", sourceID: "hls", duration: 100) == 30)
        reopened.save(titleID: "movie", sourceID: "hls", position: 40, duration: 100)
        #expect(reopened.pendingMutations.first?.sequence == 2)
        #expect(reopened.pendingMutations.first?.baseRevision == 1)
    }
}

private struct OfflineProgressTransport: MutationTransport {
    struct Failure: Error {}
    func send(_ mutation: DurableMutation) async throws -> UInt64 { throw Failure() }
}
