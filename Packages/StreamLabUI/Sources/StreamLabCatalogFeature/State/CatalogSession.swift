import Foundation
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

/// A new identity for every selection, including reselecting the same profile.
@MainActor public final class CatalogSession {
    public let id = UUID()
    public let profile: ViewerProfile
    let repository: any CatalogRepository
    let myList: MyListStore
    let languages: PlaybackLanguageStore
    let progress: PlaybackProgressStore
    public private(set) var isActive = true
    private var stores: [WeakStore] = []
    private var players: [WeakPlayer] = []
    private var progressSyncTask: Task<Void, Never>?
    private static var progressServer: MockMutationServer?

    private static func progressTransport() throws -> MockMutationServer {
        if let progressServer { return progressServer }
        // Separate revision stream from My List; both reuse DurableMutationStore.
        let url = try DurableMutationStore.defaultDirectory().appendingPathComponent("progress-mock-server.json")
        let server = try MockMutationServer(storageURL: url)
        progressServer = server
        return server
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
                try await progress.flush(using: Self.progressTransport())
            } catch {
                // Preserve the request for the next checkpoint/session launch.
                // Timed retry and conflict resolution belong to B2.
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

    public init(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        self.repository = repository
        self.myList = MyListStore(profile: profile)
        var progressDefaults = UserDefaults.standard
        var progressAccount = "local-demo"
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-test-progress-suite=") }),
           let suite = UserDefaults(suiteName: String(argument.dropFirst("--ui-test-progress-suite=".count))) {
            progressDefaults = suite
            progressAccount = "ui-test-" + String(argument.dropFirst("--ui-test-progress-suite=".count))
        }
        #endif
        self.languages = PlaybackLanguageStore(profileID: profile.id, defaults: progressDefaults)
        self.progress = PlaybackProgressStore(profileID: profile.id, defaults: progressDefaults,
                                              durable: true, accountID: progressAccount)
        self.progress.onMutation = { [weak self] in self?.scheduleProgressSync() }
        scheduleProgressSync()
    }

    func makeStore() -> CatalogStore {
        stores.removeAll { $0.value == nil }
        let store = CatalogStore(profile: profile, repository: repository)
        stores.append(WeakStore(store))
        return store
    }

    /// Called synchronously BEFORE replacing the SwiftUI subtree.
    public func invalidate() {
        for reference in players { reference.value?.saveProgress() }
        isActive = false
        progressSyncTask?.cancel()
        progressSyncTask = nil
        progress.invalidate()
        myList.invalidate()
        for reference in players { reference.value?.stop() }
        players.removeAll()
        for reference in stores { reference.value?.invalidate() }
        stores.removeAll()
    }
}

