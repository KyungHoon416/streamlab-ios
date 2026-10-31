import Foundation

/// Mock license scope. This is not a FairPlay key or a server credential.
public struct PlaybackEntitlementScope: Codable, Equatable, Sendable {
    public let accountID: String
    public let profileID: String
    public let titleID: String
    public let mediaID: String
    public init(accountID: String, profileID: String, titleID: String, mediaID: String) {
        self.accountID = accountID; self.profileID = profileID
        self.titleID = titleID; self.mediaID = mediaID
    }
}

public enum PlaybackEntitlementError: Error, Equatable, Sendable {
    case denied, expired, keyUnavailable, mismatchedScope, invalidValidity, renewalUnavailable
    public var message: String {
        switch self {
        case .expired: "재생 이용 권한이 만료되었습니다. 다시 시도하여 권한을 갱신해 주세요."
        case .keyUnavailable: "재생 키를 사용할 수 없습니다. 다시 시도해 주세요."
        case .renewalUnavailable: "재생 권한을 갱신하지 못했습니다. 다시 시도해 주세요."
        case .denied, .mismatchedScope, .invalidValidity: "이 콘텐츠의 재생 권한을 확인할 수 없습니다."
        }
    }
}

public struct PlaybackEntitlement: Codable, Equatable, Sendable {
    public enum KeyState: String, Codable, Sendable { case usable, unavailable }
    public let scope: PlaybackEntitlementScope
    public let allowed: Bool
    public let keyState: KeyState
    public let issuedAt: Date
    public let expiresAt: Date
    public init(scope: PlaybackEntitlementScope, allowed: Bool, keyState: KeyState,
                issuedAt: Date, expiresAt: Date) {
        self.scope = scope; self.allowed = allowed; self.keyState = keyState
        self.issuedAt = issuedAt; self.expiresAt = expiresAt
    }
    public func validate(for expected: PlaybackEntitlementScope, at now: Date) throws {
        guard scope == expected else { throw PlaybackEntitlementError.mismatchedScope }
        guard allowed else { throw PlaybackEntitlementError.denied }
        guard now.timeIntervalSince1970.isFinite, issuedAt.timeIntervalSince1970.isFinite,
              expiresAt.timeIntervalSince1970.isFinite, issuedAt <= now, expiresAt > issuedAt else {
            throw PlaybackEntitlementError.invalidValidity
        }
        guard now < expiresAt else { throw PlaybackEntitlementError.expired }
        guard keyState == .usable else { throw PlaybackEntitlementError.keyUnavailable }
    }
}

public protocol PlaybackEntitlementProvider: Sendable {
    func entitlement(for scope: PlaybackEntitlementScope) async throws -> PlaybackEntitlement
}

extension PlaybackEntitlementProvider {
    public func authorize(_ scope: PlaybackEntitlementScope,
                          now: @Sendable () -> Date = { Date() }) async throws -> PlaybackEntitlement {
        try Task.checkCancellation()
        let grant = try await entitlement(for: scope)
        // Providers may ignore cancellation while waiting for a reply.
        try Task.checkCancellation()
        try grant.validate(for: scope, at: now())
        return grant
    }
}
