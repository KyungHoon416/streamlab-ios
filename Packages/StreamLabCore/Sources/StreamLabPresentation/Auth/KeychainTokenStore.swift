import Foundation
import Security

public struct AccountTokens: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    public let accessToken: String
    public let refreshToken: String
    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken; self.refreshToken = refreshToken
    }
    public var description: String { "AccountTokens(redacted)" }
    public var debugDescription: String { description }
    var isValid: Bool {
        [accessToken, refreshToken].allSatisfy { !$0.isEmpty && $0.utf8.count <= 16384
            && $0.utf8.allSatisfy { (33...126).contains($0) } }
    }
}

public enum TokenStoreError: Error, Equatable {
    case invalidScope, invalidTokens, corruptItem, corruptLogoutMarker, status(Int32)
}

// Synchronous operations are confined to the store actor. No dictionaries cross actor boundaries.
protocol TokenKeychainBackend: Sendable {
    func read(service: String, account: String) -> (OSStatus, Data?)
    func add(service: String, account: String, data: Data) -> OSStatus
    func update(service: String, account: String, data: Data) -> OSStatus
    func delete(service: String, account: String) -> OSStatus
}

struct SystemTokenKeychain: TokenKeychainBackend {
    private func query(_ service: String, _ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }
    func read(service: String, account: String) -> (OSStatus, Data?) {
        var query = query(service, account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }
    func add(service: String, account: String, data: Data) -> OSStatus {
        var query = query(service, account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil)
    }
    func update(service: String, account: String, data: Data) -> OSStatus {
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        return SecItemUpdate(query(service, account) as CFDictionary, attributes as CFDictionary)
    }
    func delete(service: String, account: String) -> OSStatus {
        SecItemDelete(query(service, account) as CFDictionary)
    }
}

/// One actor per service namespace. No plaintext fallback and no token logging.
public actor KeychainTokenStore {
    // Share one store actor per service. Grants serialize session writes with logout.
    private var sessions: [String: (id: UUID, active: Bool)] = [:]
    private let service: String
    private let backend: any TokenKeychainBackend
    private let logoutMarkers: LogoutMarkers
    public init(service: String = "com.streamlab.authentication.tokens.v1", logoutDirectory: URL? = nil) throws {
        guard Self.validScope(service) else { throw TokenStoreError.invalidScope }
        self.service = service; backend = SystemTokenKeychain()
        let root = try logoutDirectory ?? FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("StreamLab/AuthSignedOut", isDirectory: true)
        logoutMarkers = LogoutMarkers(directory: root)
    }
    init(service: String, backend: any TokenKeychainBackend, logoutDirectory: URL? = nil) throws {
        guard Self.validScope(service) else { throw TokenStoreError.invalidScope }
        self.service = service; self.backend = backend
        logoutMarkers = LogoutMarkers(directory: logoutDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("streamlab-auth-test-\(UUID())", isDirectory: true))
    }
    private static func validScope(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 1024
            && !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
    private func check(_ account: String) throws {
        try Task.checkCancellation()
        guard Self.validScope(account) else { throw TokenStoreError.invalidScope }
    }
    public func read(account: String) throws -> AccountTokens? {
        try check(account)
        if try logoutMarkers.contains(service: service, account: account) { return nil }
        let (status, data) = backend.read(service: service, account: account)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw TokenStoreError.status(status) }
        guard let data, let tokens = try? JSONDecoder().decode(AccountTokens.self, from: data), tokens.isValid else {
            throw TokenStoreError.corruptItem
        }
        return tokens
    }
    public func save(_ tokens: AccountTokens, account: String) throws {
        try check(account)
        guard tokens.isValid else { throw TokenStoreError.invalidTokens }
        guard try !logoutMarkers.contains(service: service, account: account) else {
            throw AuthenticationError.invalidated
        }
        try writeTokens(tokens, account: account)
    }

    private func writeTokens(_ tokens: AccountTokens, account: String) throws {
        let data = try JSONEncoder().encode(tokens)
        var status = backend.update(service: service, account: account, data: data)
        if status == errSecItemNotFound {
            status = backend.add(service: service, account: account, data: data)
            // Another writer may have inserted the exact item. Bounded retry; never delete then add.
            if status == errSecDuplicateItem {
                status = backend.update(service: service, account: account, data: data)
            }
        }
        guard status == errSecSuccess else { throw TokenStoreError.status(status) }
    }
    public func delete(account: String) throws {
        try check(account)
        let status = backend.delete(service: service, account: account)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TokenStoreError.status(status) }
    }

    /// Call only after explicit authentication succeeds. Marker remains on any failure.
    public func signIn(_ tokens: AccountTokens, account: String) throws {
        try check(account)
        guard tokens.isValid, AuthenticationSession.valid(tokens.accessToken) else {
            throw TokenStoreError.invalidTokens
        }
        // Revoke old writers before either storage operation; marker gates crash recovery.
        sessions[account] = (UUID(), false)
        try logoutMarkers.write(service: service, account: account)
        try writeTokens(tokens, account: account)
        try logoutMarkers.clear(service: service, account: account)
        sessions.removeValue(forKey: account)
    }

    /// Re-launch cleanup. Only a durable signed-out account is eligible for deletion.
    /// Keep the marker after success: only explicit signIn may clear it.
    public func retryPendingLogout(account: String) throws {
        try check(account)
        guard try logoutMarkers.contains(service: service, account: account) else { return }
        sessions[account] = (UUID(), false)
        try delete(account: account)
    }

    func openSession(account: String) throws -> (AccountTokens, UUID)? {
        try check(account)
        if try logoutMarkers.contains(service: service, account: account) { return nil }
        // Also block in-memory restore when marker creation itself failed.
        if sessions[account]?.active == false { throw AuthenticationError.invalidated }
        guard let tokens = try read(account: account) else { return nil }
        guard AuthenticationSession.valid(tokens.accessToken) else { throw AuthenticationError.invalidCredential }
        let id = UUID()
        sessions[account] = (id, true)
        return (tokens, id)
    }

    func sessionTokens(account: String, id: UUID) throws -> AccountTokens {
        guard sessions[account]?.id == id, sessions[account]?.active == true else {
            throw AuthenticationError.invalidated
        }
        guard let tokens = try read(account: account) else { throw AuthenticationError.invalidated }
        return tokens
    }

    func saveSession(_ tokens: AccountTokens, account: String, id: UUID) throws {
        guard sessions[account]?.id == id, sessions[account]?.active == true else {
            throw AuthenticationError.invalidated
        }
        // No suspension between the grant check and the synchronous Keychain write.
        try save(tokens, account: account)
    }

    func closeSession(account: String, id: UUID) throws {
        guard sessions[account]?.id == id else { return } // Never delete a newer session.
        sessions[account] = (id, false) // Revoked even if Keychain deletion fails.
        // Record intent before deletion: a crash or Keychain error cannot restore old credentials.
        try logoutMarkers.write(service: service, account: account)
        try delete(account: account)
        // Keep both the marker and revoked grant until explicit sign-in.
    }

}
