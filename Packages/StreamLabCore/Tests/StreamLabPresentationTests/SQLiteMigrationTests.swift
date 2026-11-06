import Foundation
import Testing
import CSQLite
import StreamLabDomain
@testable import StreamLabPresentation

@Suite("B1 SQLite migration and transaction boundaries")
@MainActor struct SQLiteMigrationTests {
    private let scope = MutationScope(accountID: "migration-account", profileID: "adult-a")
    private struct Legacy: Codable {
        var version = 1
        let scope: MutationScope
        let deviceID: UUID
        var nextSequence: UInt64 = 3
        var revision: UInt64 = 0
        let values: [String: Data]
        let pending: [DurableMutation]
        var acknowledgedMyListRevisions: [String: UInt64]? = [:]
    }
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sqlite-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func legacyURL(_ root: URL) -> URL {
        let name = "s" + Data(scope.profileID.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        return DurableMutationStore.accountDirectory(directory: root, accountID: scope.accountID)
            .appendingPathComponent(name + ".json")
    }
    private func sql(_ url: URL, _ query: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else { throw SQLiteMutationDatabase.Failure.invalidSchema }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK else { throw SQLiteMutationDatabase.Failure.invalidSchema }
    }

    @Test func migrationKeepsIDsFIFODeviceAndAllProjections() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let device = UUID()
        let requests = (1...2).map { n in DurableMutation(id: UUID(), scope: scope, deviceID: device,
            sequence: UInt64(n), baseRevision: UInt64(n-1), key: "my-list", value: Data([UInt8(n)])) }
        let values = ["my-list": Data([2]), "progress-episode": Data([3]), "recent-searches": Data([4]), "quote'\0": Data()]
        let old = Legacy(scope: scope, deviceID: device, values: values, pending: requests)
        let url = legacyURL(dir)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(old).write(to: url)
        let store = try DurableMutationStore(directory: dir, scope: scope)
        #expect(store.pending == requests)
        #expect(store.values == values)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let db = url.deletingPathExtension().appendingPathExtension("sqlite")
        #expect(try Data(contentsOf: db).prefix(16) == Data("SQLite format 3\0".utf8))
        try store.set(Data([5]), forKey: "recent-searches")
        #expect(store.pending.last?.sequence == 3)
        #expect(store.pending.last?.deviceID == device)
        let restored = try DurableMutationStore(directory: dir, scope: scope)
        #expect(restored.pending == store.pending)
        #expect(restored.values == store.values)
        // Simulate COMMIT followed by death before the legacy file was removed.
        try JSONEncoder().encode(old).write(to: url)
        let afterCrash = try DurableMutationStore(directory: dir, scope: scope)
        #expect(afterCrash.values["recent-searches"] == Data([5]))
        #expect(afterCrash.pending.count == 3)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func failedTransactionRollsBackProjectionMetadataAndOutbox() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data([1]), forKey: "my-list")
        let before = store.pending
        let db = legacyURL(dir).deletingPathExtension().appendingPathExtension("sqlite")
        try sql(db, "CREATE TRIGGER fail_outbox BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT, 'injected write failure'); END")
        #expect(throws: (any Error).self) { try store.set(Data([2]), forKey: "my-list") }
        #expect(store.pending == before && store.values["my-list"] == Data([1]))
        let reopened = try DurableMutationStore(directory: dir, scope: scope)
        #expect(reopened.pending == before && reopened.values == store.values)
        try sql(db, "DROP TRIGGER fail_outbox")
        try reopened.set(Data([3]), forKey: "my-list")
        #expect(reopened.pending.last?.sequence == 2)
    }

    @Test func damagedLegacyAndUnknownSchemaAreNotReinitialized() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let old = legacyURL(dir)
        try FileManager.default.createDirectory(at: old.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("broken legacy".utf8)
        try corrupt.write(to: old)
        #expect(throws: (any Error).self) { _ = try DurableMutationStore(directory: dir, scope: scope) }
        #expect(try Data(contentsOf: old) == corrupt)
        try FileManager.default.removeItem(at: old)
        let store = try DurableMutationStore(directory: dir, scope: scope)
        try store.set(Data([1]), forKey: "my-list")
        let db = old.deletingPathExtension().appendingPathExtension("sqlite")
        try sql(db, "PRAGMA user_version=99")
        #expect(throws: (any Error).self) { _ = try DurableMutationStore(directory: dir, scope: scope) }
        #expect(throws: (any Error).self) { try store.set(Data([2]), forKey: "my-list") }
        #expect(store.values["my-list"] == Data([1]))
    }

    @Test func twoInstancesAppendWithoutLosingOtherInstanceWrites() throws {
        let dir = try root(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = try DurableMutationStore(directory: dir, scope: scope)
        let b = try DurableMutationStore(directory: dir, scope: scope)
        try a.set(Data(), forKey: "empty")
        try b.set(Data([2]), forKey: "search")
        try a.refresh()
        #expect(a.values["empty"] == Data())
        #expect(a.values["search"] == Data([2]))
        #expect(a.pending.map(\.sequence) == [1, 2])
        try a.deleteLocalData()
        #expect(throws: (any Error).self) { try b.set(Data([3]), forKey: "search") }
    }
}
