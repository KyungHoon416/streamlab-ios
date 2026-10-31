import Foundation
import StreamLabDomain

/// Deterministic, local-only license service. Never decrypts media or contacts a DRM server.
public actor MockPlaybackEntitlementProvider: PlaybackEntitlementProvider {
    public enum Outcome: Equatable, Sendable { case valid, expired, denied, keyUnavailable, renewalFailed }
    private var outcomes: [Outcome]
    private let fallback: Outcome
    private let now: @Sendable () -> Date
    public private(set) var requests = 0
    public init(outcomes: [Outcome] = [], fallback: Outcome = .valid,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.outcomes = outcomes; self.fallback = fallback; self.now = now
    }
    public func entitlement(for scope: PlaybackEntitlementScope) async throws -> PlaybackEntitlement {
        try Task.checkCancellation()
        requests += 1
        let outcome = outcomes.isEmpty ? fallback : outcomes.removeFirst()
        if case .renewalFailed = outcome { throw PlaybackEntitlementError.renewalUnavailable }
        let date = now()
        return PlaybackEntitlement(scope: scope, allowed: outcome != .denied,
            keyState: outcome == .keyUnavailable ? .unavailable : .usable,
            issuedAt: date.addingTimeInterval(-300),
            expiresAt: date.addingTimeInterval(outcome == .expired ? -1 : 300))
    }
}
