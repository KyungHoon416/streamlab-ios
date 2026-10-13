import Foundation
import StreamLabDomain
import StreamLabPresentation

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
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-test-progress-suite=") }),
           let suite = UserDefaults(suiteName: String(argument.dropFirst("--ui-test-progress-suite=".count))) {
            progressDefaults = suite
        }
        #endif
        self.languages = PlaybackLanguageStore(profileID: profile.id, defaults: progressDefaults)
        self.progress = PlaybackProgressStore(profileID: profile.id, defaults: progressDefaults)
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
        myList.invalidate()
        for reference in players { reference.value?.stop() }
        players.removeAll()
        for reference in stores { reference.value?.invalidate() }
        stores.removeAll()
    }
}

