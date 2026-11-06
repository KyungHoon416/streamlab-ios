import Foundation
import CSQLite

/// One profile database. Handles never escape a synchronous MainActor operation.
/// The application is the sole writer; projection, outbox and revision commit together.
@MainActor struct SQLiteMutationDatabase {
    struct Snapshot {
        let metadata: Data
        let values: [String: Data]
        let outbox: [Data]
    }
    enum Failure: Error { case sqlite(Int32), invalidSchema }
    let url: URL

    func read() throws -> Snapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try connection(create: false) { db in
            try execute(db, "BEGIN")
            defer { try? execute(db, "ROLLBACK") }
            let version = try scalar(db, "PRAGMA user_version")
            if version == 0 {
                // A process may die after creating the file but before its first commit.
                guard try scalar(db, "SELECT count(*) FROM sqlite_master WHERE type='table'") == 0 else {
                    throw Failure.invalidSchema
                }
                return nil
            }
            guard version == 1 else { throw Failure.invalidSchema }
            let headers = try rows(db, "SELECT payload FROM metadata WHERE singleton=1")
            guard headers.count == 1 else { throw Failure.invalidSchema }
            var values = [String: Data]()
            try statement(db, "SELECT key, value FROM local_values") { query in
                while try step(query) == SQLITE_ROW {
                    let keyBytes = blob(query, 0)
                    guard let key = String(data: keyBytes, encoding: .utf8), values[key] == nil else {
                        throw Failure.invalidSchema
                    }
                    values[key] = blob(query, 1)
                }
            }
            return Snapshot(metadata: headers[0], values: values,
                            outbox: try rows(db, "SELECT payload FROM outbox ORDER BY position"))
        }
    }

    func write(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                               withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                             ofItemAtPath: url.deletingLastPathComponent().path)
        #endif
        try connection(create: true) { db in
            // Rollback journal + FULL sync; do not acknowledge a write before COMMIT succeeds.
            try execute(db, "PRAGMA synchronous=FULL")
            try execute(db, "BEGIN IMMEDIATE")
            do {
                let version = try scalar(db, "PRAGMA user_version")
                guard version == 0 || version == 1 else { throw Failure.invalidSchema }
                try execute(db, "CREATE TABLE IF NOT EXISTS metadata (singleton INTEGER PRIMARY KEY CHECK(singleton=1), payload BLOB NOT NULL)")
                try execute(db, "CREATE TABLE IF NOT EXISTS local_values (key BLOB PRIMARY KEY NOT NULL, value BLOB NOT NULL) WITHOUT ROWID")
                try execute(db, "CREATE TABLE IF NOT EXISTS outbox (position INTEGER PRIMARY KEY, payload BLOB NOT NULL)")
                try execute(db, "DELETE FROM metadata; DELETE FROM local_values; DELETE FROM outbox")
                try statement(db, "INSERT INTO metadata VALUES (1, ?)") { query in
                    try bind(snapshot.metadata, to: query, index: 1)
                    guard try step(query) == SQLITE_DONE else { throw Failure.invalidSchema }
                }
                try statement(db, "INSERT INTO local_values VALUES (?, ?)") { query in
                    for key in snapshot.values.keys.sorted() {
                        try bind(Data(key.utf8), to: query, index: 1)
                        try bind(snapshot.values[key]!, to: query, index: 2)
                        guard try step(query) == SQLITE_DONE else { throw Failure.invalidSchema }
                        sqlite3_reset(query)
                        sqlite3_clear_bindings(query)
                    }
                }
                try statement(db, "INSERT INTO outbox VALUES (?, ?)") { query in
                    for (position, payload) in snapshot.outbox.enumerated() {
                        try check(sqlite3_bind_int64(query, 1, Int64(position)))
                        try bind(payload, to: query, index: 2)
                        guard try step(query) == SQLITE_DONE else { throw Failure.invalidSchema }
                        sqlite3_reset(query)
                        sqlite3_clear_bindings(query)
                    }
                }
                try execute(db, "PRAGMA user_version=1")
                try execute(db, "COMMIT")
            } catch {
                try? execute(db, "ROLLBACK")
                throw error
            }
        }
    }

    func delete() throws {
        // No resident connections: explicit logout can remove all database artifacts.
        for suffix in ["", "-journal", "-wal", "-shm"] {
            let path = url.path + suffix
            if FileManager.default.fileExists(atPath: path) { try FileManager.default.removeItem(atPath: path) }
        }
    }

    private func connection<T>(create: Bool, _ body: (OpaquePointer) throws -> T) throws -> T {
        var handle: OpaquePointer?
        let code = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | (create ? SQLITE_OPEN_CREATE : 0), nil)
        defer { if let handle { sqlite3_close(handle) } }
        try check(code)
        guard let handle else { throw Failure.invalidSchema }
        // Another process holding the DB must not block the UI for seconds.
        try check(sqlite3_busy_timeout(handle, 0))
        return try body(handle)
    }

    private func check(_ code: Int32) throws {
        guard code == SQLITE_OK else { throw Failure.sqlite(code) }
    }
    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        try check(sqlite3_exec(db, sql, nil, nil, nil))
    }
    private func statement<T>(_ db: OpaquePointer, _ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        var query: OpaquePointer?
        try check(sqlite3_prepare_v2(db, sql, -1, &query, nil))
        guard let query else { throw Failure.invalidSchema }
        defer { sqlite3_finalize(query) }
        return try body(query)
    }
    private func step(_ query: OpaquePointer) throws -> Int32 {
        let code = sqlite3_step(query)
        guard code == SQLITE_ROW || code == SQLITE_DONE else { throw Failure.sqlite(code) }
        return code
    }
    private func bind(_ data: Data, to query: OpaquePointer, index: Int32) throws {
        guard data.count <= Int(Int32.max) else { throw Failure.invalidSchema }
        if data.isEmpty { try check(sqlite3_bind_zeroblob(query, index, 0)); return }
        try data.withUnsafeBytes { bytes in
            try check(sqlite3_bind_blob(query, index, bytes.baseAddress, Int32(data.count),
                                       unsafeBitCast(-1, to: sqlite3_destructor_type.self)))
        }
    }
    private func blob(_ query: OpaquePointer, _ column: Int32) -> Data {
        let size = Int(sqlite3_column_bytes(query, column))
        guard size > 0, let pointer = sqlite3_column_blob(query, column) else { return Data() }
        return Data(bytes: pointer, count: size)
    }
    private func scalar(_ db: OpaquePointer, _ sql: String) throws -> Int32 {
        try statement(db, sql) { query in
            guard try step(query) == SQLITE_ROW else { throw Failure.invalidSchema }
            return sqlite3_column_int(query, 0)
        }
    }
    private func rows(_ db: OpaquePointer, _ sql: String) throws -> [Data] {
        try statement(db, sql) { query in
            var result = [Data]()
            while try step(query) == SQLITE_ROW { result.append(blob(query, 0)) }
            return result
        }
    }
}
