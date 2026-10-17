import Foundation
import Security
import Testing
@testable import StreamLabPresentation

@Suite("C2 durable authentication logout")
struct DurableAuthenticationLogoutTests {
    private struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("auth-logout-\(UUID())")
        let backend = KeychainTokenStoreTests.Backend()
        let first = AccountTokens(accessToken: "expired", refreshToken: "refresh-one")
        let second = AccountTokens(accessToken: "new-access", refreshToken: "new-refresh")
        func store(service: String = "durable") throws -> KeychainTokenStore {
            try KeychainTokenStore(service: service, backend: backend, logoutDirectory: root)
        }
        func clean() { try? FileManager.default.removeItem(at: root) }
        func item(account: String = "a") throws -> AccountTokens? {
            let (_, data) = backend.read(service: "durable", account: account)
            return try data.map { try JSONDecoder().decode(AccountTokens.self, from: $0) }
        }
    }

    @Test func deletionFailureSurvivesStoreRecreationAndCleanupKeepsSignedOut() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        let (_, id) = try #require(try await store.openSession(account: "a"))
        f.backend.fail(errSecInteractionNotAllowed)
        await #expect(throws: TokenStoreError.status(errSecInteractionNotAllowed)) {
            try await store.closeSession(account: "a", id: id)
        }
        f.backend.fail(nil)
        #expect(try f.item() == f.first) // Actual credential still exists; marker blocks its use.
        let reopened = try f.store()
        let before = f.backend.count
        #expect(try await reopened.openSession(account: "a") == nil)
        #expect(try await reopened.read(account: "a") == nil)
        #expect(f.backend.count == before) // No Keychain read on blocked restore.
        await #expect(throws: AuthenticationError.invalidated) { try await reopened.save(f.second, account: "a") }
        try await reopened.retryPendingLogout(account: "a")
        try await reopened.retryPendingLogout(account: "a")
        #expect(try f.item() == nil)
        #expect(try LogoutMarkers(directory: f.root).contains(service: "durable", account: "a"))
        #expect(try await f.store().openSession(account: "a") == nil)
    }

    @Test func explicitSignInReplacesCredentialsAndOldLogoutCannotDeleteThem() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        let (_, oldID) = try #require(try await store.openSession(account: "a"))
        try await store.closeSession(account: "a", id: oldID)
        try await store.signIn(f.second, account: "a")
        try await store.closeSession(account: "a", id: oldID)
        try await store.retryPendingLogout(account: "a") // No marker: cannot delete signed-in account.
        let (tokens, _) = try #require(try await f.store().openSession(account: "a"))
        #expect(tokens == f.second)
        await #expect(throws: AuthenticationError.invalidated) {
            try await store.saveSession(f.first, account: "a", id: oldID)
        }
    }

    @Test func failedExplicitSignInNeverClearsSignedOutMarker() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        f.backend.fail(errSecAuthFailed)
        await #expect(throws: TokenStoreError.status(errSecAuthFailed)) {
            try await store.signIn(f.second, account: "a")
        }
        f.backend.fail(nil)
        #expect(try f.item() == f.first)
        #expect(try await f.store().openSession(account: "a") == nil)
        try await store.signIn(f.second, account: "a")
        #expect(try await f.store().read(account: "a") == f.second)
    }

    @Test func markerAloneModelsCrashBeforeKeychainDeletion() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        try LogoutMarkers(directory: f.root).write(service: "durable", account: "a")
        #expect(try f.item() == f.first)
        #expect(try await f.store().openSession(account: "a") == nil)
        try await f.store().retryPendingLogout(account: "a")
        #expect(try f.item() == nil)
    }

    @Test func corruptMarkerFailsClosedWithoutReadingKeychain() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        let path = LogoutMarkers(directory: f.root).marker(service: "durable", account: "a")
        try Data("corrupt".utf8).write(to: path)
        let before = f.backend.count
        await #expect(throws: TokenStoreError.corruptLogoutMarker) { try await f.store().openSession(account: "a") }
        #expect(f.backend.count == before)
    }

    @Test func unavailableMarkerDirectoryFailsLogoutAndRestoreClosed() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); try await store.signIn(f.first, account: "a")
        let (_, id) = try #require(try await store.openSession(account: "a"))
        try FileManager.default.removeItem(at: f.root)
        try Data("blocked".utf8).write(to: f.root)
        let before = f.backend.count
        await #expect(throws: (any Error).self) { try await store.closeSession(account: "a", id: id) }
        await #expect(throws: (any Error).self) { try await f.store().openSession(account: "a") }
        #expect(f.backend.count == before)
        try FileManager.default.removeItem(at: f.root)
        // Same-session retry commits the marker before deleting the credential.
        try await store.closeSession(account: "a", id: id)
        #expect(try f.item() == nil)
    }

    @Test func accountAndServiceIsolationAndNoTokenInMetadata() async throws {
        let f = Fixture(); defer { f.clean() }
        let store = try f.store(); let other = try f.store(service: "other")
        try await store.signIn(f.first, account: "a")
        try await store.signIn(f.second, account: "b")
        try await other.signIn(f.second, account: "a")
        let (_, id) = try #require(try await store.openSession(account: "a"))
        try await store.closeSession(account: "a", id: id)
        #expect(try await store.read(account: "b") == f.second)
        #expect(try await other.read(account: "a") == f.second)
        let files = try FileManager.default.contentsOfDirectory(at: f.root, includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        for file in files {
            #expect(file.lastPathComponent.count == 75) // SHA256 hex + .signed-out
            #expect(try String(contentsOf: file, encoding: .utf8) == "signed-out-v1")
        }
    }
}
