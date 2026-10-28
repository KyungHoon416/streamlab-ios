import Combine
import Foundation
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

/// No cross-profile cache. Detail lookup still performs repository authorization.
enum RecentTitleResolver {
    struct Resolution: Sendable {
        var titles: [String: CatalogTitle] = [:]
        var failed = false
    }
    private struct Lookup: Sendable { let id: String; let title: CatalogTitle?; let failed: Bool }

    static func resolve(ids: [String], lookup: @escaping @Sendable (String) async throws -> CatalogTitle?) async -> Resolution {
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        return await withTaskGroup(of: Lookup.self) { group in
            var next = 0
            func enqueue(_ id: String) {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        return Lookup(id: id, title: try await lookup(id), failed: false)
                    } catch { return Lookup(id: id, title: nil, failed: !(error is CancellationError)) }
                }
            }
            while next < min(4, unique.count), !Task.isCancelled {
                enqueue(unique[next]); next += 1
            }
            var result = Resolution()
            for await value in group {
                if Task.isCancelled { group.cancelAll(); continue }
                if let title = value.title, title.id == value.id { result.titles[value.id] = title }
                result.failed = result.failed || value.failed
                if next < unique.count { enqueue(unique[next]); next += 1 }
            }
            return result
        }
    }
}

@MainActor final class HomeRecentModel: ObservableObject {
    struct Item: Identifiable, Equatable {
        let title: CatalogTitle
        let entry: PlaybackProgressStore.Entry
        let source: PlaybackModel.Source
        var id: String { title.id }
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.title == rhs.title && lhs.source == rhs.source &&
            lhs.entry.position == rhs.entry.position && lhs.entry.duration == rhs.entry.duration
        }
    }
    struct Snapshot: Equatable { var items: [Item] = []; var failed = false }
    @Published private(set) var snapshot = Snapshot()
    private let session: CatalogSession
    private var generation = UUID()

    init(session: CatalogSession) { self.session = session }

    func refresh() async {
        guard session.isActive, !Task.isCancelled else { return }
        let span = HomeStartupTrace.begin("HomeRecentWait")
        defer { withExtendedLifetime(span) {} }
        let ticket = UUID()
        generation = ticket
        let entries = session.progress.recent()
        // HLS and downloaded HLS share a progress ID; preserve the previous first-match policy.
        let sources = Dictionary(PlaybackModel.Source.allCases.map { ($0.progressID, $0) },
                                 uniquingKeysWith: { first, _ in first })
        let eligible = entries.filter { sources[$0.sourceID] != nil }
        let repository = session.repository
        let profile = session.profile
        let resolved = await RecentTitleResolver.resolve(ids: eligible.map(\.titleID)) {
            try await repository.detail(id: $0, profile: profile)
        }
        guard !Task.isCancelled, session.isActive, generation == ticket else { return }
        // Preserve progress-store ordering even when detail responses arrive out of order.
        let items = eligible.compactMap { entry -> Item? in
            guard let title = resolved.titles[entry.titleID], title.canView(in: profile),
                  let source = sources[entry.sourceID] else { return nil }
            return Item(title: title, entry: entry, source: source)
        }
        let updated = Snapshot(items: items, failed: resolved.failed)
        guard snapshot != updated else { return }
        HomeStartupTrace.measure("HomeRecentPublish") { snapshot = updated }
    }
}
