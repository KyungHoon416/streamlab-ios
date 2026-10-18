import Foundation
import Security
import Testing
@testable import StreamLabPresentation

@Suite("C2 explicit authentication sign-in", .timeLimit(.minutes(1)))
struct AuthenticationSignInTests {
    private func store() throws -> (KeychainTokenStore, KeychainTokenStoreTests.Backend) {
        let backend = KeychainTokenStoreTests.Backend()
        return (try KeychainTokenStore(service: "sign-in-tests", backend: backend), backend)
    }

    @Test func signInPersistsThenRotatesAndLogsOut() async throws {
        let (store, _) = try store()
        let first = AccountTokens(accessToken: "access-one", refreshToken: "refresh-one")
        let renewed = AccountTokens(accessToken: "access-two", refreshToken: "refresh-two")
        let session = try await AuthenticationSession.signIn(account: "a", tokens: first, store: store) { refresh in
            #expect(refresh == "refresh-one")
            return renewed
        }
        #expect(try await store.read(account: "a") == first)
        let old = try await session.current()
        #expect(old.token == first.accessToken)
        let refreshed = try await session.refreshed(after: old)
        #expect(refreshed.token == renewed.accessToken)
        #expect(try await store.read(account: "a") == renewed)
        try await session.logout()
        #expect(try await store.read(account: "a") == nil)
        await #expect(throws: AuthenticationError.invalidated) { try await session.current() }
    }

    @Test func failedSignInKeepsRestoreBlockedUntilExplicitRetry() async throws {
        let (store, backend) = try store()
        let first = AccountTokens(accessToken: "old-access", refreshToken: "old-refresh")
        let next = AccountTokens(accessToken: "new-access", refreshToken: "new-refresh")
        try await store.save(first, account: "a")
        backend.fail(errSecInteractionNotAllowed)
        await #expect(throws: TokenStoreError.status(errSecInteractionNotAllowed)) {
            try await AuthenticationSession.signIn(account: "a", tokens: next, store: store) { _ in next }
        }
        backend.fail(nil)
        let restored = try await AuthenticationSession.restore(account: "a", store: store) { _ in next }
        #expect(restored == nil)
        let session = try await AuthenticationSession.signIn(account: "a", tokens: next, store: store) { _ in next }
        #expect(try await session.current().token == "new-access")
        try await session.logout()
    }

    @Test func invalidSignInDoesNotReplaceExistingCredentials() async throws {
        let (store, _) = try store()
        let first = AccountTokens(accessToken: "valid-access", refreshToken: "valid-refresh")
        let session = try await AuthenticationSession.signIn(account: "a", tokens: first, store: store) { _ in first }
        await #expect(throws: TokenStoreError.invalidTokens) {
            try await AuthenticationSession.signIn(account: "a",
                tokens: AccountTokens(accessToken: "bad bearer", refreshToken: "refresh"), store: store) { _ in first }
        }
        #expect(try await store.read(account: "a") == first)
        try await session.logout()
        #expect(try await store.read(account: "a") == nil)
    }

    @Test func concurrentSignInsKeepTheirOwnTokensAndOldLogoutCannotDeleteWinner() async throws {
        let (store, _) = try store()
        let a = AccountTokens(accessToken: "access-a", refreshToken: "refresh-a")
        let b = AccountTokens(accessToken: "access-b", refreshToken: "refresh-b")
        async let first = AuthenticationSession.signIn(account: "same", tokens: a, store: store) { _ in a }
        async let second = AuthenticationSession.signIn(account: "same", tokens: b, store: store) { _ in b }
        let (sessionA, sessionB) = try await (first, second)
        #expect(try await sessionA.current().token == a.accessToken)
        #expect(try await sessionB.current().token == b.accessToken)
        let winner = try #require(try await store.read(account: "same"))
        let stale = winner == a ? sessionB : sessionA
        let current = winner == a ? sessionA : sessionB
        try await stale.logout()
        #expect(try await store.read(account: "same") == winner)
        try await current.logout()
        #expect(try await store.read(account: "same") == nil)
    }

    @Test func accountLogoutWithoutRestoredSessionBlocksReopen() async throws {
        let (store, _) = try store()
        let tokens = AccountTokens(accessToken: "demo-access", refreshToken: "demo-refresh")
        try await store.save(tokens, account: "a")
        #expect(try await store.hasLogoutMarker(account: "a") == false)
        try await store.signOut(account: "a")
        #expect(try await store.hasLogoutMarker(account: "a"))
        #expect(try await store.read(account: "a") == nil)
        let restored = try await AuthenticationSession.restore(account: "a", store: store) { _ in tokens }
        #expect(restored == nil)
        let fresh = try await AuthenticationSession.signIn(account: "a", tokens: tokens, store: store) { _ in tokens }
        #expect(try await store.hasLogoutMarker(account: "a") == false)
        try await fresh.logout()
    }

    @Test func accountLogoutFailureKeepsMarkerAndOtherAccountUntouched() async throws {
        let (store, backend) = try store()
        let tokens = AccountTokens(accessToken: "demo-access", refreshToken: "demo-refresh")
        try await store.save(tokens, account: "a")
        try await store.save(tokens, account: "b")
        backend.fail(errSecInteractionNotAllowed)
        await #expect(throws: TokenStoreError.status(errSecInteractionNotAllowed)) {
            try await store.signOut(account: "a")
        }
        #expect(try await store.hasLogoutMarker(account: "a"))
        backend.fail(nil)
        #expect(try await store.read(account: "a") == nil)
        #expect(try await store.read(account: "b") == tokens)
        try await store.signOut(account: "a")
        #expect(try await store.hasLogoutMarker(account: "a"))
    }

}
