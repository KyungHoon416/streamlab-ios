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
    case invalidScope, invalidTokens, corruptItem, status(Int32)
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
    private let service: String
    private let backend: any TokenKeychainBackend
    public init(service: String = "com.streamlab.authentication.tokens.v1") throws {
        guard Self.validScope(service) else { throw TokenStoreError.invalidScope }
        self.service = service; backend = SystemTokenKeychain()
    }
    init(service: String, backend: any TokenKeychainBackend) throws {
        guard Self.validScope(service) else { throw TokenStoreError.invalidScope }
        self.service = service; self.backend = backend
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
}
