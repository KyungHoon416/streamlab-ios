import Foundation

public struct OfflineDownload: Codable, Identifiable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case queued, downloading, paused, complete, expired, failed, removing }
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
    public var expiresAt: Date?
    public static let mockValidity: TimeInterval = 7 * 24 * 60 * 60
    public func isExpired(at now: Date) -> Bool {
        state == .expired || (state == .complete && expiresAt.map { now >= $0 } == true)
    }
    @discardableResult public mutating func expire(at now: Date) -> Bool {
        guard state == .complete, isExpired(at: now) else { return false }
        state = .expired
        return true
    }
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

    public struct Usage: Equatable, Sendable {
        public let completedBytes: Int64
        public let otherFileBytes: Int64
        public let reservedBytes: Int64
        public var chargedBytes: Int64 { completedBytes + otherFileBytes + reservedBytes }
        public var remainingBytes: Int64 { max(0, capacity - chargedBytes) }
        public var fraction: Double { min(1, Double(chargedBytes) / Double(capacity)) }
    }

    /// Same accounting as admission: queued jobs reserve nothing until started.
    /// Reservations include only the extra allowance above already recorded bytes.
    public static func usage(in records: [OfflineDownload]) throws -> Usage {
        var completed: Int64 = 0, other: Int64 = 0, reserved: Int64 = 0, total: Int64 = 0
        for record in records {
            let charge = try chargedBytes(for: record)
            let sum = total.addingReportingOverflow(charge)
            guard !sum.overflow else { throw Failure.invalidSize }
            total = sum.partialValue
            if record.state == .complete { completed += record.bytes }
            else { other += record.bytes }
            reserved += charge - record.bytes
        }
        return Usage(completedBytes: completed, otherFileBytes: other, reservedBytes: reserved)
    }

    private static func chargedBytes(for record: OfflineDownload) throws -> Int64 {
        guard record.bytes >= 0 else { throw Failure.invalidSize }
        return (record.state == .downloading || record.state == .paused || record.state == .removing)
            ? max(record.bytes, reservation) : record.bytes
    }

    public static func evictions(in records: [OfflineDownload], required: Int64 = reservation,
                                 protected: Set<UUID> = [], minimumReclaim: Int64 = 0) throws -> [UUID] {
        guard required > 0, required <= capacity, minimumReclaim >= 0 else { throw Failure.invalidSize }
        var used: Int64 = 0
        for record in records {
            let charge = try chargedBytes(for: record)
            let sum = used.addingReportingOverflow(charge)
            guard !sum.overflow else { throw Failure.invalidSize }
            used = sum.partialValue
        }
        let candidates = records.filter { ($0.state == .complete || $0.state == .expired) && !$0.pinned && !protected.contains($0.id) }
            .sorted { $0.lastUsed == $1.lastUsed ? $0.id.uuidString < $1.id.uuidString : $0.lastUsed < $1.lastUsed }
        var selected: [UUID] = []
        var reclaimed: Int64 = 0
        for item in candidates where used > capacity - required || reclaimed < minimumReclaim {
            used -= item.bytes; reclaimed += item.bytes; selected.append(item.id)
        }
        guard used <= capacity - required, reclaimed >= minimumReclaim else { throw Failure.insufficientSpace }
        return selected
    }

    /// Canonicalize the system callback's no-follow alias, then require the same
    /// app container. Never accept an arbitrary absolute path from the journal.
    public static func relativePath(location: URL, home: URL) -> String? {
        guard location.isFileURL else { return nil }
        var path = location.path
        if path.hasPrefix("/.nofollow/") { path = String(path.dropFirst("/.nofollow".count)) }
        guard let destination = resolvedURL(URL(fileURLWithPath: path)), let root = resolvedURL(home) else { return nil }
        let resolved = containerComparisonPath(destination.path)
        let prefix = containerComparisonPath(root.path) + "/"
        guard resolved.hasPrefix(prefix) else { return nil }
        let relative = String(resolved.dropFirst(prefix.count))
        return localURL(path: relative, home: home) == nil ? nil : relative
    }

    /// Compare Darwin's /var alias after resolving symlinks. On an iPhone,
    /// sandbox permissions can leave /var unresolved on one side of the comparison.
    /// This is comparison-only: retain the URL rooted in the actual app home for I/O.
    static func containerComparisonPath(_ resolvedPath: String) -> String {
        if resolvedPath == "/private/var" || resolvedPath.hasPrefix("/private/var/") {
            return String(resolvedPath.dropFirst("/private".count))
        }
        return resolvedPath
    }

    /// A new package does not exist yet. Foundation may leave its parent symlink
    /// unresolved, so resolve the nearest existing ancestor (including dangling
    /// links) before reattaching the missing path components.
    private static func resolvedURL(_ url: URL, remainingLinks: Int = 40) -> URL? {
        var ancestor = url.absoluteURL
        var missing: [String] = []
        while true {
            if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: ancestor.path) {
                guard remainingLinks > 0,
                      let resolved = resolvedURL(URL(fileURLWithPath: target, relativeTo: ancestor.deletingLastPathComponent()).absoluteURL,
                                                 remainingLinks: remainingLinks - 1) else { return nil }
                return missing.reversed().reduce(resolved) { $0.appendingPathComponent($1) }
            }
            if FileManager.default.fileExists(atPath: ancestor.path) || ancestor.path == "/" {
                return missing.reversed().reduce(ancestor.resolvingSymlinksInPath().standardizedFileURL) {
                    $0.appendingPathComponent($1)
                }
            }
            missing.append(ancestor.lastPathComponent)
            ancestor.deleteLastPathComponent()
        }
    }

    /// Persist only a relative system asset URL, and reject escapes on reload.
    public static func localURL(path: String, home: URL) -> URL? {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        guard let root = resolvedURL(home), let value = resolvedURL(root.appendingPathComponent(path)) else { return nil }
        guard containerComparisonPath(value.path).hasPrefix(containerComparisonPath(root.path) + "/"),
              value.pathExtension == "movpkg" else { return nil }
        return value
    }
}
