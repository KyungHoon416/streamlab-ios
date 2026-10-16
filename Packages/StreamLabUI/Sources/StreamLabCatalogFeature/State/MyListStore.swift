import Combine
import Foundation
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

/// Local-first snapshots and immutable pending requests share one atomic journal.
/// Detail/playback still reauthorize via Repository.
@MainActor final class MyListStore: ObservableObject {
    @Published private(set) var items: [CatalogTitle] = []
    @Published var errorMessage: String?
    private let profile: ViewerProfile
    private var queue: DurableMutationStore?
    private var active = true
    private var syncTask: Task<Void, Never>?
    // One actor owns the mock server file for the entire app process.
    private static var server: MockMutationServer?
    private static func transport() throws -> MockMutationServer {
        if let server { return server }
        let url = try DurableMutationStore.defaultDirectory().appendingPathComponent("mock-server.json")
        let created = try MockMutationServer(storageURL: url)
        server = created
        return created
    }
    private let snapshotKey = "my-list"

    init(profile: ViewerProfile, defaults: UserDefaults = .standard, accountID: String = "local-demo") {
        self.profile = profile
        do {
            // The app currently has profile selection, not authenticated accounts.
            let scope = MutationScope(accountID: accountID, profileID: profile.id)
            queue = try DurableMutationStore(directory: DurableMutationStore.defaultDirectory(),
                                             scope: scope, seed: accountID == "local-demo" ? legacySeed(defaults: defaults) : [:])
            items = try read()
            scheduleSync()
        } catch {
            errorMessage = "저장된 리스트를 불러오지 못했습니다. 기존 데이터는 유지됩니다."
        }
    }

    func contains(_ title: CatalogTitle) -> Bool { items.contains { $0.id == title.id } }

    func toggle(_ title: CatalogTitle) {
        guard active, title.canView(in: profile) else { return }
        do {
            guard let queue else { throw MutationQueueError.inactive }
            try queue.refresh()
            var updated = try read()
            if updated.contains(where: { $0.id == title.id }) {
                updated.removeAll { $0.id == title.id }
            } else { updated.insert(title, at: 0) }
            try queue.set(JSONEncoder().encode(updated), forKey: snapshotKey)
            items = updated
            scheduleSync()
        } catch {
            errorMessage = "리스트를 저장하지 못했습니다. 다시 시도해 주세요."
        }
    }

    func refresh() {
        guard active else { return }
        do {
            guard let queue else { throw MutationQueueError.inactive }
            try queue.refresh()
            items = try read()
            scheduleSync()
        } catch {
            errorMessage = "저장된 리스트를 불러오지 못했습니다."
        }
    }

    func invalidate() {
        active = false
        syncTask?.cancel()
        queue?.invalidate()
        items = []
    }

    func waitForSync() async { await syncTask?.value }

    static func clearMockAccount(_ accountID: String, devices: Set<UUID>) async throws {
        try await transport().forgetAccount(accountID, revoking: devices)
    }

    private func scheduleSync() {
        guard active, syncTask == nil, let queue else { return }
        syncTask = Task { [weak self] in
            defer { self?.syncTask = nil }
            do {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test-mutation-offline") {
                    throw URLError(.notConnectedToInternet)
                }
                #endif
                try await queue.flush(using: RetryingMutationTransport(base: Self.transport()))
            } catch {
                // Local save already succeeded. Retain requests for the next refresh,
                // change, or session launch after the bounded retry budget is exhausted.
            }
        }
    }

    private func legacySeed(defaults: UserDefaults) throws -> [String: Data] {
        let key = "streamlab.my-list.v1.\(profile.id)"
        guard let data = defaults.data(forKey: key) else { return [:] }
        let titles = try JSONDecoder().decode([CatalogTitle].self, from: data)
        // Evaluated only when no journal exists. Keep the legacy data for rollback.
        return [snapshotKey: try JSONEncoder().encode(filtered(titles))]
    }

    private func read() throws -> [CatalogTitle] {
        guard let data = queue?.values[snapshotKey] else { return [] }
        return filtered(try JSONDecoder().decode([CatalogTitle].self, from: data))
    }

    private func filtered(_ titles: [CatalogTitle]) -> [CatalogTitle] {
        var seen: Set<String> = []
        return titles.filter { $0.canView(in: profile) && seen.insert($0.id).inserted }
    }
}
