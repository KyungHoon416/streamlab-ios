import Combine
import Foundation
import StreamLabDomain

/// Explicitly submitted searches only; live typing never writes history.
@MainActor public final class RecentSearchStore: ObservableObject {
    @Published public private(set) var terms: [String] = []
    @Published public private(set) var persistenceError: String?
    public var onMutation: (@MainActor () -> Void)?
    public var pendingMutations: [DurableMutation] { queue?.pending ?? [] }
    public static let limit = 20
    public static let maximumLength = 100
    private let snapshotKey = "recent-searches"
    private var queue: DurableMutationStore?
    private var active = true

    public init(profileID: String, accountID: String = "local-demo", directory: URL? = nil) {
        do {
            let root: URL
            if let directory { root = directory }
            else {
                root = try DurableMutationStore.defaultDirectory()
                    .appendingPathComponent("RecentSearches", isDirectory: true)
            }
            queue = try DurableMutationStore(directory: root,
                scope: MutationScope(accountID: accountID, profileID: profileID))
            terms = try read()
        } catch {
            persistenceError = "최근 검색어를 불러오지 못했습니다. 기존 데이터는 유지됩니다."
        }
    }

    public func record(_ query: String) {
        let term = Self.normalized(query)
        guard !term.isEmpty else { return }
        update { existing in
            [term] + existing.filter { $0.lowercased() != term.lowercased() }
        }
    }

    public func remove(_ term: String) {
        let identity = Self.normalized(term).lowercased()
        update(deletion: .term(identity)) { $0.filter { $0.lowercased() != identity } }
    }

    public func clear() { update(deletion: .all) { _ in [] } }

    public func refresh() {
        guard active else { return }
        do {
            guard let queue else { throw MutationQueueError.inactive }
            try queue.refresh()
            terms = try read()
            persistenceError = nil
        } catch { persistenceError = "최근 검색어를 불러오지 못했습니다." }
    }

    public func flush(using transport: any MutationTransport,
                      snapshots: (any MutationSnapshotSource)? = nil) async throws {
        guard active, let queue else { throw MutationQueueError.inactive }
        defer {
            // Reconciliation may commit locally before a subsequent send fails.
            if active {
                do { terms = try read() }
                catch { persistenceError = "최근 검색어를 불러오지 못했습니다." }
            }
        }
        try await queue.flush(using: transport, serverWins: snapshots, preserveSearchDeletions: true)
    }

    public func invalidate() {
        active = false
        onMutation = nil
        queue?.invalidate()
        terms = []
    }

    private static func normalized(_ query: String) -> String {
        String(query.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .precomposedStringWithCanonicalMapping.prefix(maximumLength))
    }

    private func read() throws -> [String] {
        guard let data = queue?.values[snapshotKey] else { return [] }
        let decoded = try JSONDecoder().decode([String].self, from: data)
        var seen = Set<String>()
        return Array(decoded.map { Self.normalized($0) }.filter {
            !$0.isEmpty && seen.insert($0.lowercased()).inserted
        }.prefix(Self.limit))
    }

    private func update(deletion: SearchDeletion? = nil, _ transform: ([String]) -> [String]) {
        guard active else { return }
        do {
            guard let queue else { throw MutationQueueError.inactive }
            try queue.refresh()
            let current = try read()
            let updated = Array(transform(current).prefix(Self.limit))
            guard updated != current else {
                terms = current
                persistenceError = nil
                // A repeated submit may retry pending work without adding a duplicate.
                onMutation?()
                return
            }
            let data: Data?
            if updated.isEmpty { data = nil }
            else { data = try JSONEncoder().encode(updated) }
            try queue.set(data, forKey: snapshotKey, searchDeletion: deletion)
            terms = updated
            persistenceError = nil
            onMutation?()
        } catch {
            persistenceError = "최근 검색어를 저장하지 못했습니다. 다시 시도해 주세요."
        }
    }
}
