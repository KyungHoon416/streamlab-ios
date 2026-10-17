import Foundation
import CryptoKit

/// Synchronous, actor-confined metadata only. Never stores access/refresh tokens.
struct LogoutMarkers: Sendable {
    let directory: URL

    func marker(service: String, account: String) -> URL {
        let digest = SHA256.hash(data: Data((service + "\0" + account).utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".signed-out")
    }

    private func prepare() throws {
        guard directory.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        // Validate/create the parent even for a read: an inaccessible or non-directory
        // parent must never be mistaken for an absent marker (signed-in state).
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw CocoaError(.fileReadCorruptFile) }
    }

    func contains(service: String, account: String) throws -> Bool {
        try prepare()
        do {
            let data = try Data(contentsOf: marker(service: service, account: account))
            guard data == Data("signed-out-v1".utf8) else { throw TokenStoreError.corruptLogoutMarker }
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return false
        }
    }

    func write(service: String, account: String) throws {
        try prepare()
        try Data("signed-out-v1".utf8).write(to: marker(service: service, account: account), options: .atomic)
    }

    func clear(service: String, account: String) throws {
        try prepare()
        try FileManager.default.removeItem(at: marker(service: service, account: account))
    }
}
