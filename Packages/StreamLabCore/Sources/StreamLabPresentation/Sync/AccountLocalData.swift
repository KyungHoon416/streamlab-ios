import Foundation

/// Logout marker survives an interrupted cleanup. The caller must clean its Mock
/// transports before finishCleanup; entering a session requires explicit signIn.
@MainActor public final class AccountLocalData {
    public let accountID: String
    private let root: URL
    private let defaults: UserDefaults
    private var cleanupCompleted = false
    private var marker: URL {
        DurableMutationStore.accountDirectory(directory: root.appendingPathComponent("SignedOut"),
                                               accountID: accountID).appendingPathComponent("marker")
    }
    public var isSignedOut: Bool { FileManager.default.fileExists(atPath: marker.path) }
    public var directories: [URL] {
        [root, root.appendingPathComponent("Progress"), root.appendingPathComponent("RecentSearches")]
    }

    /// Defaults must be the account's own suite (standard for the single demo account).
    public init(root: URL, accountID: String, defaults: UserDefaults) {
        self.root = root
        self.accountID = accountID
        self.defaults = defaults
    }

    public func beginLogout() throws -> Set<UUID> {
        cleanupCompleted = false
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
        try Data("signed-out".utf8).write(to: marker, options: .atomic)
        return DurableMutationStore.revokeAccount(accountID, directories: directories)
    }

    public func finishCleanup() throws {
        cleanupCompleted = false
        guard isSignedOut else { throw CocoaError(.fileNoSuchFile) }
        for directory in directories {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
               !isDirectory.boolValue { throw CocoaError(.fileReadCorruptFile) }
            let account = DurableMutationStore.accountDirectory(directory: directory, accountID: accountID)
            if FileManager.default.fileExists(atPath: account.path) {
                try FileManager.default.removeItem(at: account)
            }
        }
        // These v1 keys have no account component; only use the supplied account suite.
        let prefixes = ["streamlab.my-list.v1.", "streamlab.progress.v1.", "streamlab.languages.v1."]
        for key in defaults.dictionaryRepresentation().keys where prefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        cleanupCompleted = true
    }

    public func signIn() throws {
        guard cleanupCompleted else { throw CocoaError(.fileReadNoPermission) }
        try FileManager.default.removeItem(at: marker)
        cleanupCompleted = false
    }
}
