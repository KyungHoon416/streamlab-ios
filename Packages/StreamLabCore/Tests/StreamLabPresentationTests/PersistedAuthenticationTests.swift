import Foundation
import Security
import Testing
@testable import StreamLabPresentation

@Suite("C2 persisted authentication", .timeLimit(.minutes(1)))
struct PersistedAuthenticationTests {
    private let first = AccountTokens(accessToken: "expired", refreshToken: "refresh-one")
    private let second = AccountTokens(accessToken: "renewed", refreshToken: "refresh-two")
    private actor Gate {
        var calls = 0
        private var continuation: CheckedContinuation<AccountTokens, Never>?
        func wait() async -> AccountTokens {
            calls += 1
            // Deliberately ignores cancellation to exercise a late server response.
            return await withCheckedContinuation { continuation = $0 }
        }
        func finish(_ tokens: AccountTokens) { continuation?.resume(returning: tokens); continuation = nil }
    }
    private func waitUntil(_ condition: () async -> Bool) async throws {
        let clock = ContinuousClock(); let limit = clock.now.advanced(by: .seconds(5))
        while !(await condition()) {
            guard clock.now < limit else { throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    private func store() throws -> (KeychainTokenStore, KeychainTokenStoreTests.Backend) {
        let backend = KeychainTokenStoreTests.Backend()
        return (try KeychainTokenStore(service: "persisted-tests", backend: backend), backend)
    }

    @Test func persistsRotatedPairBeforePublishingSharedLease() async throws {
        let (store, _) = try store(); try await store.save(first, account: "a")
        let gate = Gate()
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { token in
            #expect(token == "refresh-one")
            return await gate.wait()
        })
        let old = try await session.current()
        let tasks = (0..<8).map { _ in Task { try await session.refreshed(after: old) } }
        try await waitUntil { await session.waitingCount == 8 }
        try await waitUntil { await gate.calls == 1 }
        await gate.finish(second)
        for task in tasks {
            let lease = try await task.value
            #expect(lease.token == "renewed")
            #expect(try await store.read(account: "a") == second)
        }
        #expect(await gate.calls == 1)
        let reopened = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in
            AccountTokens(accessToken: "unused", refreshToken: "unused")
        })
        #expect(try await reopened.current().token == "renewed")
    }

    @Test func failedSaveDoesNotPublishAndLatchesFailure() async throws {
        let (store, backend) = try store(); try await store.save(first, account: "a")
        let renewed = second
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in
            backend.fail(errSecInteractionNotAllowed)
            return renewed
        })
        let old = try await session.current()
        await #expect(throws: AuthenticationError.refreshFailed) { try await session.refreshed(after: old) }
        await #expect(throws: AuthenticationError.refreshFailed) { try await session.current() }
        backend.fail(nil)
        #expect(try await store.read(account: "a") == first)
    }

    @Test func logoutDeletesAndRejectsLateUncooperativeRefresh() async throws {
        let (store, _) = try store()
        try await store.save(first, account: "a"); try await store.save(first, account: "b")
        let gate = Gate()
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in await gate.wait() })
        let old = try await session.current()
        let task = Task { try await session.refreshed(after: old) }
        try await waitUntil { await gate.calls == 1 }
        try await session.logout()
        await #expect(throws: AuthenticationError.invalidated) { try await task.value }
        await gate.finish(second)
        try await waitUntil { await session.completedRefreshCount == 1 }
        #expect(try await store.read(account: "a") == nil)
        #expect(try await store.read(account: "b") == first)
    }

    @Test func deletionFailureRevokesWritesAndCanBeRetried() async throws {
        let (store, backend) = try store(); try await store.save(first, account: "a")
        let renewed = second
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in renewed })
        backend.fail(errSecInteractionNotAllowed)
        await #expect(throws: TokenStoreError.status(errSecInteractionNotAllowed)) { try await session.logout() }
        await #expect(throws: AuthenticationError.invalidated) { try await session.current() }
        backend.fail(nil)
        await #expect(throws: AuthenticationError.invalidated) { try await store.openSession(account: "a") }
        try await session.logout()
        #expect(try await store.read(account: "a") == nil)
    }

    @Test func staleGrantCannotOverwriteOrDeleteNewSession() async throws {
        let (store, _) = try store(); try await store.save(first, account: "a")
        let (_, oldID) = try #require(try await store.openSession(account: "a"))
        let (_, newID) = try #require(try await store.openSession(account: "a"))
        try await store.saveSession(second, account: "a", id: newID)
        await #expect(throws: AuthenticationError.invalidated) { try await store.saveSession(first, account: "a", id: oldID) }
        try await store.closeSession(account: "a", id: oldID)
        #expect(try await store.read(account: "a") == second)
        try await store.closeSession(account: "a", id: newID)
    }

    @Test func invalidRenewedBearerIsNeverSaved() async throws {
        let (store, _) = try store(); try await store.save(first, account: "a")
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in
            AccountTokens(accessToken: "invalid:bearer", refreshToken: "rotated")
        })
        let old = try await session.current()
        await #expect(throws: AuthenticationError.refreshFailed) { try await session.refreshed(after: old) }
        #expect(try await store.read(account: "a") == first)
    }

    @Test func timedOutRefreshCannotPersistLateTokens() async throws {
        let (store, _) = try store(); try await store.save(first, account: "a")
        let refreshGate = Gate(); let deadlineGate = Gate()
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store,
            refresh: { _ in await refreshGate.wait() }, deadline: { _ = await deadlineGate.wait() }))
        let old = try await session.current()
        let task = Task { try await session.refreshed(after: old) }
        try await waitUntil {
            let refreshCalls = await refreshGate.calls
            let deadlineCalls = await deadlineGate.calls
            return refreshCalls == 1 && deadlineCalls == 1
        }
        await deadlineGate.finish(first)
        await #expect(throws: AuthenticationError.refreshTimedOut) { try await task.value }
        await refreshGate.finish(second)
        try await waitUntil { await session.completedRefreshCount == 2 }
        #expect(try await store.read(account: "a") == first)
    }

    @Test func cancelledLogoutCallerStillDeletesCredentials() async throws {
        let (store, _) = try store(); try await store.save(first, account: "a")
        let renewed = second
        let session = try #require(try await AuthenticationSession.restore(account: "a", store: store) { _ in renewed })
        let gate = Gate()
        let task = Task {
            _ = await gate.wait()
            try await session.logout()
        }
        try await waitUntil { await gate.calls == 1 }
        task.cancel()
        await gate.finish(first)
        try await task.value
        #expect(try await store.read(account: "a") == nil)
        await #expect(throws: AuthenticationError.invalidated) { try await session.current() }
    }

}
