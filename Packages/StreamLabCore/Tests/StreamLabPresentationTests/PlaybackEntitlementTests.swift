import Foundation
import Testing
import StreamLabDomain
@testable import StreamLabPresentation

@Suite("C2 Mock playback entitlement", .timeLimit(.minutes(1)))
struct PlaybackEntitlementTests {
    private let now = Date(timeIntervalSince1970: 1000)
    private let scope = PlaybackEntitlementScope(accountID: "a", profileID: "p", titleID: "t", mediaID: "m")
    private func grant(allowed: Bool = true, key: PlaybackEntitlement.KeyState = .usable,
                       issued: Double = 900, expiry: Double = 1100) -> PlaybackEntitlement {
        PlaybackEntitlement(scope: scope, allowed: allowed, keyState: key,
            issuedAt: Date(timeIntervalSince1970: issued), expiresAt: Date(timeIntervalSince1970: expiry))
    }
    @Test func expiresAtBoundaryEvenForLocalMedia() throws {
        try grant().validate(for: scope, at: now)
        #expect(throws: PlaybackEntitlementError.expired) {
            try grant().validate(for: scope, at: Date(timeIntervalSince1970: 1100))
        }
    }
    @Test func everyScopeComponentMustMatch() {
        for other in [
            PlaybackEntitlementScope(accountID: "b", profileID: "p", titleID: "t", mediaID: "m"),
            PlaybackEntitlementScope(accountID: "a", profileID: "kids", titleID: "t", mediaID: "m"),
            PlaybackEntitlementScope(accountID: "a", profileID: "p", titleID: "other", mediaID: "m"),
            PlaybackEntitlementScope(accountID: "a", profileID: "p", titleID: "t", mediaID: "other")
        ] {
            #expect(throws: PlaybackEntitlementError.mismatchedScope) { try grant().validate(for: other, at: now) }
        }
    }
    @Test func denialAndMissingKeyFailClosed() {
        #expect(throws: PlaybackEntitlementError.denied) { try grant(allowed: false).validate(for: scope, at: now) }
        #expect(throws: PlaybackEntitlementError.keyUnavailable) {
            try grant(key: .unavailable).validate(for: scope, at: now)
        }
    }
    @Test func invalidDatesNeverAuthorize() {
        for value in [grant(issued: 1001), grant(expiry: 800), grant(expiry: .infinity)] {
            #expect(throws: PlaybackEntitlementError.invalidValidity) { try value.validate(for: scope, at: now) }
        }
        #expect(throws: PlaybackEntitlementError.invalidValidity) {
            try grant().validate(for: scope, at: Date(timeIntervalSince1970: .nan))
        }
    }
    @Test func explicitRenewalCanRecoverWithoutChangingScope() async throws {
        let date = now
        let provider = MockPlaybackEntitlementProvider(outcomes: [.expired, .renewalFailed, .keyUnavailable], now: { date })
        for error in [PlaybackEntitlementError.expired, .renewalUnavailable, .keyUnavailable] {
            await #expect(throws: error) { try await provider.authorize(scope, now: { date }) }
        }
        let renewed = try await provider.authorize(scope, now: { date })
        #expect(renewed.scope == scope)
        #expect(await provider.requests == 4)
    }
    @Test func persistentDenialNeverBecomesSuccess() async {
        let date = now
        let provider = MockPlaybackEntitlementProvider(fallback: .denied, now: { date })
        for _ in 0..<4 {
            await #expect(throws: PlaybackEntitlementError.denied) { try await provider.authorize(scope, now: { date }) }
        }
        #expect(await provider.requests == 4)
    }
    private actor Gate: PlaybackEntitlementProvider {
        let grant: PlaybackEntitlement
        var reply: CheckedContinuation<PlaybackEntitlement, Never>?
        var started: CheckedContinuation<Void, Never>?
        init(_ grant: PlaybackEntitlement) { self.grant = grant }
        func entitlement(for scope: PlaybackEntitlementScope) async throws -> PlaybackEntitlement {
            await withCheckedContinuation { continuation in
                reply = continuation
                started?.resume(); started = nil
            }
        }
        func waitForRequest() async {
            if reply != nil { return }
            await withCheckedContinuation { started = $0 }
        }
        func finish() { reply?.resume(returning: grant); reply = nil }
    }
    @Test func cancelledRequestRejectsLateSuccessfulGrant() async {
        let gate = Gate(grant()); let scope = scope; let date = now
        let task = Task { try await gate.authorize(scope, now: { date }) }
        await gate.waitForRequest()
        task.cancel()
        await gate.finish()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
