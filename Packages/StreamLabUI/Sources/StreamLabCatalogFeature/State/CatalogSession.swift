import Foundation
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData
import StreamLabDesignSystem

/// A new identity for every selection, including reselecting the same profile.
@MainActor public final class CatalogSession {
    public let id = UUID()
    public let profile: ViewerProfile
    let accountID: String
    let repository: any CatalogRepository
    let myList: MyListStore
    let languages: PlaybackLanguageStore
    let progress: PlaybackProgressStore
    let recentSearches: RecentSearchStore
    public private(set) var isActive = true
    private var stores: [WeakStore] = []
    private var players: [WeakPlayer] = []
    private var networkObserver: NetworkPathObserver?
    private var recovery: ConnectionRecoveryCoordinator?
    private var searchSyncTask: Task<Void, Never>?
    private var progressSyncTask: Task<Void, Never>?

    private static func progressTransport() async throws -> MockMutationServer {
        let url = try DurableMutationStore.defaultDirectory().appendingPathComponent("progress-mock-server.json")
        return try await MockServerRegistry.shared.server(at: url)
    }

    private func scheduleProgressSync() {
        guard isActive, progressSyncTask == nil else { return }
        let progress = self.progress
        progressSyncTask = Task { [weak self] in
            defer { self?.progressSyncTask = nil }
            do {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test-mutation-offline") {
                    throw URLError(.notConnectedToInternet)
                }
                #endif
                let server = try await Self.progressTransport()
                try Task.checkCancellation()
                try await progress.flush(using: RetryingMutationTransport(base: server), snapshots: server)
            } catch {
                // Preserve the request for the next checkpoint/session launch.
                // The next mutation, session launch, or connection recovery can retry.
            }
        }
    }

    private static func searchTransport() async throws -> MockMutationServer {
        let url = try DurableMutationStore.defaultDirectory().appendingPathComponent("search-mock-server.json")
        return try await MockServerRegistry.shared.server(at: url)
    }

    private func scheduleSearchSync() {
        guard isActive, searchSyncTask == nil else { return }
        let recentSearches = self.recentSearches
        searchSyncTask = Task { [weak self] in
            defer { self?.searchSyncTask = nil }
            do {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-test-mutation-offline") {
                    throw URLError(.notConnectedToInternet)
                }
                #endif
                let server = try await Self.searchTransport()
                try Task.checkCancellation()
                try await recentSearches.flush(using: RetryingMutationTransport(base: server), snapshots: server)
            } catch {
                // Keep pending history changes for the next submit or session launch.
            }
        }
    }

    private final class WeakPlayer {
        weak var value: PlaybackModel?
        init(_ value: PlaybackModel) { self.value = value }
    }

    func register(_ player: PlaybackModel) {
        players.removeAll { $0.value == nil }
        players.append(WeakPlayer(player))
    }

    private final class WeakStore {
        weak var value: CatalogStore?
        init(_ value: CatalogStore) { self.value = value }
    }

    public convenience init(profile: ViewerProfile, repository: any CatalogRepository) {
        self.init(profile: profile, repository: repository, configuration: CatalogAccount.configuration())
    }

    /// Test sessions can use isolated account/defaults without changing app launch arguments.
    init(profile: ViewerProfile, repository: any CatalogRepository,
         configuration: (id: String, defaults: UserDefaults)) {
        self.profile = profile
        self.accountID = configuration.id
        self.repository = repository
        let progressDefaults = configuration.defaults
        let progressAccount = configuration.id
        self.myList = MyListStore(profile: profile, defaults: progressDefaults, accountID: progressAccount)
        self.languages = PlaybackLanguageStore(profileID: profile.id, defaults: progressDefaults)
        self.progress = PlaybackProgressStore(profileID: profile.id, defaults: progressDefaults,
                                              durable: true, accountID: progressAccount)
        self.recentSearches = RecentSearchStore(profileID: profile.id, accountID: progressAccount)
        self.recentSearches.onMutation = { [weak self] in self?.scheduleSearchSync() }
        self.progress.onMutation = { [weak self] in self?.scheduleProgressSync() }
        scheduleProgressSync()
        scheduleSearchSync()
        let recovery = ConnectionRecoveryCoordinator { [weak self] in
            guard let self, self.isActive else { return }
            // A recovery edge arriving during an existing retry must not be lost.
            await self.waitForSync()
            guard self.isActive, !Task.isCancelled else { return }
            self.myList.refresh()
            self.scheduleProgressSync()
            self.scheduleSearchSync()
            await self.waitForSync()
        }
        self.recovery = recovery
        networkObserver = NetworkPathObserver { [weak recovery] available in
            recovery?.update(isAvailable: available)
        }
        networkObserver?.start()
    }

    /// Foreground observation catches reconnects that happened while suspended.
    public func setSynchronizationActive(_ active: Bool) {
        guard isActive else { return }
        if active {
            recovery?.resume()
            networkObserver?.start()
        } else {
            networkObserver?.stop()
            recovery?.suspend()
        }
    }

    func makeStore() -> CatalogStore {
        stores.removeAll { $0.value == nil }
        let store = CatalogStore(profile: profile, repository: repository)
        stores.append(WeakStore(store))
        return store
    }

    /// Called synchronously BEFORE replacing the SwiftUI subtree.
    public func invalidate(saveProgress: Bool = true) {
        if saveProgress {
            for reference in players { reference.value?.saveProgress() }
        }
        isActive = false
        networkObserver?.stop()
        recovery?.suspend()
        progressSyncTask?.cancel()
        progress.invalidate()
        searchSyncTask?.cancel()
        recentSearches.invalidate()
        languages.invalidate()
        myList.invalidate()
        for reference in players { reference.value?.stop() }
        players.removeAll()
        for reference in stores { reference.value?.invalidate() }
        stores.removeAll()
    }

    func waitForSync() async {
        await progressSyncTask?.value
        await searchSyncTask?.value
        await myList.waitForSync()
    }

    static func clearMockAccount(_ accountID: String, devices: Set<UUID>) async throws {
        try await MyListStore.clearMockAccount(accountID, devices: devices)
        try await progressTransport().forgetAccount(accountID, revoking: devices)
        try await searchTransport().forgetAccount(accountID, revoking: devices)
    }

}

