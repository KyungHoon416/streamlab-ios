import StreamLabCatalogData
import StreamLabPresentation

/// One in-process server for debug device A/B. Never shared with local UserDefaults progress.
@MainActor enum PlaybackSyncDemo {
    static var coordinator = PlaybackSyncCoordinator(server: MockProgressServer())
    static func reset() { coordinator = PlaybackSyncCoordinator(server: MockProgressServer()) }
}
