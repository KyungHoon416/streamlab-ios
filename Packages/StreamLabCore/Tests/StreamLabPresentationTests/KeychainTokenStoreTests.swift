import Foundation
import Security
import Testing
@testable import StreamLabPresentation

@Suite("C2 token store policy")
struct KeychainTokenStoreTests {
    // The lock protects every mutable field in this synchronous backend test double.
    final class Backend: TokenKeychainBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String: Data] = [:]
        private var forced: OSStatus?
        private var duplicate = false
        private var calls = 0
        func fail(_ status: OSStatus?) { lock.withLock { forced = status } }
        func raceOnAdd() { lock.withLock { duplicate = true } }
        var count: Int { lock.withLock { calls } }
        func corrupt() { lock.withLock { items["test:a"] = Data([0]) } }
        func read(service: String, account: String) -> (OSStatus, Data?) {
            lock.withLock {
                calls += 1
                if let forced { return (forced, nil) }
                let data = items[service + ":" + account]
                return (data == nil ? errSecItemNotFound : errSecSuccess, data)
            }
        }
        func add(service: String, account: String, data: Data) -> OSStatus {
            lock.withLock {
                calls += 1
                if let forced { return forced }
                let key = service + ":" + account
                if duplicate { duplicate = false; items[key] = Data(); return errSecDuplicateItem }
                if items[key] != nil { return errSecDuplicateItem }
                items[key] = data; return errSecSuccess
            }
        }
        func update(service: String, account: String, data: Data) -> OSStatus {
            lock.withLock {
                calls += 1
                if let forced { return forced }
                let key = service + ":" + account
                guard items[key] != nil else { return errSecItemNotFound }
                items[key] = data; return errSecSuccess
            }
        }
        func delete(service: String, account: String) -> OSStatus {
            lock.withLock {
                calls += 1
                if let forced { return forced }
                return items.removeValue(forKey: service + ":" + account) == nil ? errSecItemNotFound : errSecSuccess
            }
        }
    }
    private let first = AccountTokens(accessToken: "dummy-access", refreshToken: "dummy-refresh")
    private let second = AccountTokens(accessToken: "dummy-new-access", refreshToken: "dummy-new-refresh")

    @Test func isolatesAccountsUpdatesAndDeletesOnlyOne() async throws {
        let backend = Backend(); let store = try KeychainTokenStore(service: "test", backend: backend)
        #expect(try await store.read(account: "a") == nil)
        try await store.save(first, account: "a"); try await store.save(first, account: "b")
        try await store.save(second, account: "a")
        #expect(try await store.read(account: "a") == second)
        #expect(try await store.read(account: "b") == first)
        try await store.delete(account: "a"); try await store.delete(account: "a")
        #expect(try await store.read(account: "b") == first)
    }
    @Test func duplicateInsertRetriesUpdateWithoutDeleting() async throws {
        let backend = Backend(); backend.raceOnAdd()
        let store = try KeychainTokenStore(service: "test", backend: backend)
        try await store.save(first, account: "a")
        #expect(backend.count == 3)
        #expect(try await store.read(account: "a") == first)
    }
    @Test func failuresAreNotMissingItemsOrSuccessfulWrites() async throws {
        let backend = Backend(); let store = try KeychainTokenStore(service: "test", backend: backend)
        try await store.save(first, account: "a")
        for status in [errSecInteractionNotAllowed, errSecAuthFailed, errSecMissingEntitlement] {
            backend.fail(status)
            await #expect(throws: TokenStoreError.status(status)) { try await store.read(account: "a") }
            await #expect(throws: TokenStoreError.status(status)) { try await store.save(second, account: "a") }
            await #expect(throws: TokenStoreError.status(status)) { try await store.delete(account: "a") }
        }
        backend.fail(nil)
        #expect(try await store.read(account: "a") == first)
    }
    @Test func corruptPayloadFailsWithoutSilentDeletion() async throws {
        let backend = Backend(); backend.corrupt()
        let store = try KeychainTokenStore(service: "test", backend: backend)
        await #expect(throws: TokenStoreError.corruptItem) { try await store.read(account: "a") }
        await #expect(throws: TokenStoreError.corruptItem) { try await store.read(account: "a") }
        #expect(backend.count == 2)
    }
    @Test func invalidInputDoesNotTouchKeychain() async throws {
        let backend = Backend(); let store = try KeychainTokenStore(service: "test", backend: backend)
        #expect(throws: TokenStoreError.invalidScope) { try KeychainTokenStore(service: " ") }
        await #expect(throws: TokenStoreError.invalidScope) { try await store.delete(account: "") }
        await #expect(throws: TokenStoreError.invalidTokens) {
            try await store.save(AccountTokens(accessToken: "", refreshToken: "dummy"), account: "a")
        }
        #expect(backend.count == 0)
        #expect(String(describing: first) == "AccountTokens(redacted)")
        #expect(String(reflecting: first) == "AccountTokens(redacted)")
    }
    @Test func cancelledOperationDoesNotWrite() async throws {
        let backend = Backend(); let store = try KeychainTokenStore(service: "test", backend: backend)
        let tokens = first
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await store.save(tokens, account: "a")
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(backend.count == 0)
    }
}

@Suite("C2 system Keychain integration", .enabled(if:
    ProcessInfo.processInfo.environment["STREAMLAB_TEST_KEYCHAIN"] == "1"))
struct SystemKeychainTokenStoreTests {
    @Test func storesReopensUpdatesIsolatesAndRemovesDummyTokens() async throws {
        let service = "com.streamlab.tests.tokens." + UUID().uuidString
        let store = try KeychainTokenStore(service: service)
        let tokens = AccountTokens(accessToken: "fixture-access", refreshToken: "fixture-refresh")
        let updated = AccountTokens(accessToken: "fixture-access-new", refreshToken: "fixture-refresh-new")
        do {
            try await store.save(tokens, account: "fixture-a")
            try await store.save(tokens, account: "fixture-b")
            let reopened = try KeychainTokenStore(service: service)
            #expect(try await reopened.read(account: "fixture-a") == tokens)
            try await reopened.save(updated, account: "fixture-a")
            #expect(try await store.read(account: "fixture-a") == updated)
            try await store.delete(account: "fixture-a")
            #expect(try await reopened.read(account: "fixture-a") == nil)
            #expect(try await reopened.read(account: "fixture-b") == tokens)
            try await store.delete(account: "fixture-b")
            #expect(try await reopened.read(account: "fixture-b") == nil)
        } catch {
            // Cleanup is scoped to the two dummy items; never delete an entire keychain/service.
            do { try await store.delete(account: "fixture-a") } catch { Issue.record("Dummy item A cleanup failed") }
            do { try await store.delete(account: "fixture-b") } catch { Issue.record("Dummy item B cleanup failed") }
            throw error
        }
        print("KEYCHAIN PASS dummy-item-lifecycle")
    }
}
