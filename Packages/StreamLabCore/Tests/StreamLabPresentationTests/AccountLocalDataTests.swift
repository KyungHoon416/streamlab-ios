import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B1 account logout cleanup")
@MainActor struct AccountLocalDataTests {
    @MainActor private struct Fixture {
        let name = "logout-\(UUID())"
        let root: URL
        let defaults: UserDefaults
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            defaults = try #require(UserDefaults(suiteName: name))
        }
        func lifecycle() -> AccountLocalData { AccountLocalData(root: root, accountID: "a", defaults: defaults) }
        func clean() { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
    }

    @Test func deletesEveryProfileAndStoreButPreservesOtherAccountAndDefaults() throws {
        let f = try Fixture()
        defer { f.clean() }
        let lifecycle = f.lifecycle()
        var stores: [DurableMutationStore] = []
        for directory in lifecycle.directories {
            for profile in ["adult-a", "adult-b", "kids"] {
                let store = try DurableMutationStore(directory: URL(fileURLWithPath: directory.path, isDirectory: true),
                    scope: MutationScope(accountID: "a", profileID: profile))
                try store.set(Data("private".utf8), forKey: "record")
                stores.append(store)
            }
        }
        let other = try DurableMutationStore(directory: f.root,
            scope: MutationScope(accountID: "b", profileID: "adult-a"))
        try other.set(Data("keep".utf8), forKey: "record")
        f.defaults.set("legacy", forKey: "streamlab.my-list.v1.adult-a")
        f.defaults.set("legacy", forKey: "streamlab.progress.v1.example")
        f.defaults.set("legacy", forKey: "streamlab.languages.v1.example")
        f.defaults.set("keep", forKey: "unrelated.setting")
        let devices = try lifecycle.beginLogout()
        #expect(devices.count == 9)
        #expect(stores.allSatisfy { $0.values.isEmpty && $0.pending.isEmpty })
        try lifecycle.finishCleanup()
        for directory in lifecycle.directories {
            #expect(!FileManager.default.fileExists(atPath:
                DurableMutationStore.accountDirectory(directory: directory, accountID: "a").path))
        }
        #expect(f.defaults.object(forKey: "streamlab.my-list.v1.adult-a") == nil)
        #expect(f.defaults.object(forKey: "streamlab.progress.v1.example") == nil)
        #expect(f.defaults.object(forKey: "streamlab.languages.v1.example") == nil)
        #expect(f.defaults.string(forKey: "unrelated.setting") == "keep")
        #expect(other.values["record"] == Data("keep".utf8))
        try other.set(Data("still active".utf8), forKey: "record")
        #expect(throws: MutationQueueError.inactive) { try stores[0].set(Data(), forKey: "record") }
    }

    @Test func interruptedLogoutStaysSignedOutUntilCleanupAndExplicitSignIn() throws {
        let f = try Fixture()
        defer { f.clean() }
        let first = f.lifecycle()
        _ = try first.beginLogout()
        let reopened = f.lifecycle()
        #expect(reopened.isSignedOut)
        #expect(throws: (any Error).self) { try reopened.signIn() }
        _ = try reopened.beginLogout()
        try reopened.finishCleanup()
        #expect(reopened.isSignedOut)
        try reopened.signIn()
        #expect(!f.lifecycle().isSignedOut)
    }

    @Test func failedDeletionDoesNotPermitSignInAndCanBeRetried() throws {
        let f = try Fixture()
        defer { f.clean() }
        let lifecycle = f.lifecycle()
        _ = try lifecycle.beginLogout()
        // A regular file cannot be traversed as the Progress directory.
        let progress = f.root.appendingPathComponent("Progress")
        try Data("blocked".utf8).write(to: progress)
        // The path lookup can report absent under a non-directory parent. Verify
        // the explicit root validation rejects this instead of declaring success.
        #expect(throws: (any Error).self) { try lifecycle.finishCleanup() }
        #expect(throws: (any Error).self) { try lifecycle.signIn() }
        #expect(lifecycle.isSignedOut)
        try FileManager.default.removeItem(at: progress)
        try lifecycle.finishCleanup()
        try lifecycle.signIn()
        #expect(!lifecycle.isSignedOut)
    }

    @Test func mockForgetsAccountAndRejectsOldRequestsAcrossServerRelaunch() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let url = f.root.appendingPathComponent("server.json")
        let server = try MockMutationServer(storageURL: url)
        let a = MutationScope(accountID: "a", profileID: "adult")
        let b = MutationScope(accountID: "b", profileID: "adult")
        let old = DurableMutation(id: UUID(), scope: a, deviceID: UUID(), sequence: 1,
                                  baseRevision: 0, key: "history", value: Data("private".utf8))
        _ = try await server.send(old)
        _ = try await server.send(DurableMutation(id: UUID(), scope: b, deviceID: UUID(), sequence: 1,
            baseRevision: 0, key: "history", value: Data("keep".utf8)))
        try await server.forgetAccount("a", revoking: [old.deviceID])
        let reopened = try MockMutationServer(storageURL: url)
        do { _ = try await reopened.send(old); Issue.record("Revoked request recreated data") }
        catch { #expect(error as? MutationQueueError == .inactive) }
        #expect(await reopened.values(for: a).isEmpty)
        #expect(await reopened.values(for: b)["history"] == Data("keep".utf8))
        _ = try await reopened.send(DurableMutation(id: UUID(), scope: a, deviceID: UUID(), sequence: 1,
            baseRevision: 0, key: "history", value: Data("new session".utf8)))
        #expect(await reopened.revision(for: a) == 1)
    }

    @Test func repeatedRevocationRetainsIDsOfTasksStillInFlight() throws {
        let f = try Fixture()
        defer { f.clean() }
        let queue = try DurableMutationStore(directory: f.root, scope: MutationScope(accountID: "a", profileID: "adult"))
        try queue.set(Data(), forKey: "record")
        let lifecycle = f.lifecycle()
        let first = try lifecycle.beginLogout()
        let retry = try lifecycle.beginLogout()
        #expect(first == retry)
        #expect(first.count == 1)
    }

    @Test func lateAcknowledgementCannotRecreateDeletedJournal() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let queue = try DurableMutationStore(directory: f.root, scope: MutationScope(accountID: "a", profileID: "adult"))
        try queue.set(Data("private".utf8), forKey: "record")
        let transport = LogoutBarrierTransport()
        let task = Task { try await queue.flush(using: transport) }
        await transport.waitUntilSent()
        let lifecycle = f.lifecycle()
        let devices = try lifecycle.beginLogout()
        try await transport.server.forgetAccount("a", revoking: devices)
        try lifecycle.finishCleanup()
        await transport.release()
        do { try await task.value; Issue.record("Late ACK accepted") }
        catch { #expect(error as? MutationQueueError == .inactive) }
        #expect(!FileManager.default.fileExists(atPath:
            DurableMutationStore.accountDirectory(directory: f.root, accountID: "a").path))
    }

    @Test func languageCallbackAfterInvalidationCannotRestorePreferences() throws {
        let f = try Fixture()
        defer { f.clean() }
        let languages = PlaybackLanguageStore(profileID: "adult", defaults: f.defaults)
        languages.setSubtitles(.language("en"))
        languages.invalidate()
        let lifecycle = f.lifecycle()
        _ = try lifecycle.beginLogout()
        try lifecycle.finishCleanup()
        languages.setSubtitles(.language("ko"))
        let newLanguages = PlaybackLanguageStore(profileID: "adult", defaults: f.defaults)
        #expect(newLanguages.preferences.subtitles == .off)
    }
}

private actor LogoutBarrierTransport: MutationTransport {
    let server = MockMutationServer()
    private var held: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func send(_ mutation: DurableMutation) async throws -> UInt64 {
        let revision = try await server.send(mutation)
        await withCheckedContinuation { continuation in
            held = continuation
            waiter?.resume()
            waiter = nil
        }
        return revision
    }
    func waitUntilSent() async {
        if held != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() { held?.resume(); held = nil }
}
