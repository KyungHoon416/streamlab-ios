import Foundation

public struct OfflineDownload: Codable, Identifiable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case queued, downloading, complete, failed, removing }
    public let id: UUID
    public let accountID: String
    public let profileID: String
    public let titleID: String
    public let title: String
    public var state: State = .queued
    public var relativePath: String?
    public var bytes: Int64 = 0
    public var pinned = false
    public var lastUsed: Date
    public var message: String?
    public init(id: UUID = UUID(), accountID: String, profileID: String, titleID: String, title: String, now: Date = Date()) {
        self.id = id; self.accountID = accountID; self.profileID = profileID
        self.titleID = titleID; self.title = title; self.lastUsed = now
    }
}

/// Decimal GB. Reservations bound concurrent work; native callbacks can arrive
/// after bytes are written, so this is not an OS-level instantaneous disk quota.
public enum OfflineDownloadBudget {
    public static let capacity: Int64 = 1_000_000_000
    public static let reservation: Int64 = 500_000_000
    public static let concurrentLimit = 2
    public enum Failure: Error { case invalidSize, insufficientSpace }

    public static func evictions(in records: [OfflineDownload], required: Int64 = reservation,
                                 protected: Set<UUID> = []) throws -> [UUID] {
        guard required > 0, required <= capacity else { throw Failure.invalidSize }
        var used: Int64 = 0
        for record in records {
            guard record.bytes >= 0 else { throw Failure.invalidSize }
            let charge = (record.state == .downloading || record.state == .removing) ? max(record.bytes, reservation) : record.bytes
            let sum = used.addingReportingOverflow(charge)
            guard !sum.overflow else { throw Failure.invalidSize }
            used = sum.partialValue
        }
        let candidates = records.filter { $0.state == .complete && !$0.pinned && !protected.contains($0.id) }
            .sorted { $0.lastUsed == $1.lastUsed ? $0.id.uuidString < $1.id.uuidString : $0.lastUsed < $1.lastUsed }
        var selected: [UUID] = []
        for item in candidates where used > capacity - required {
            used -= item.bytes; selected.append(item.id)
        }
        guard used <= capacity - required else { throw Failure.insufficientSpace }
        return selected
    }

    /// Canonicalize the system callback's no-follow alias, then require the same
    /// app container. Never accept an arbitrary absolute path from the journal.
    public static func relativePath(location: URL, home: URL) -> String? {
        guard location.isFileURL else { return nil }
        var path = location.path
        if path.hasPrefix("/.nofollow/") { path = String(path.dropFirst("/.nofollow".count)) }
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = home.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard resolved.hasPrefix(prefix) else { return nil }
        let relative = String(resolved.dropFirst(prefix.count))
        return localURL(path: relative, home: home) == nil ? nil : relative
    }

    /// Persist only a relative system asset URL, and reject escapes on reload.
    public static func localURL(path: String, home: URL) -> URL? {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        let root = home.resolvingSymlinksInPath().standardizedFileURL
        let value = root.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        guard value.path.hasPrefix(root.path + "/"), value.pathExtension == "movpkg" else { return nil }
        return value
    }
}
