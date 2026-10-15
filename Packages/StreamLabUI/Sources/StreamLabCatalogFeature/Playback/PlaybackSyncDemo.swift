import StreamLabCatalogData
import StreamLabPresentation

/// One in-process server for debug device A/B. Never shared with local UserDefaults progress.
@MainActor enum PlaybackSyncDemo {
    static let coordinator = PlaybackSyncCoordinator(server: MockProgressServer())
}
