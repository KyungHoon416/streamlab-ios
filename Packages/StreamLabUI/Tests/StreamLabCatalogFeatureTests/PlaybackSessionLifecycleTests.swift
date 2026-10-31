import AVFoundation
import Foundation
import MediaPlayer
import StreamLabCatalogData
import StreamLabDomain
import StreamLabPresentation
import XCTest
@testable import StreamLabCatalogFeature
@testable import StreamLabDesignSystem

@MainActor private final class PlaybackWeakReference<Value: AnyObject> {
    weak var value: Value?
    init(_ value: Value?) { self.value = value }
}

final class PlaybackSessionLifecycleTests: XCTestCase {
    @MainActor
    private func waitForPlayback(_ model: PlaybackModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while ContinuousClock.now < deadline {
            if model.status == .playing, (model.player?.rate ?? 0) > 0,
               PlaybackNowPlaying.shared.session?.nowPlayingInfoCenter.nowPlayingInfo != nil { return }
            if case .failed(let message) = model.status {
                XCTFail("Bundled playback failed: \(message)")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Bundled playback did not become ready: \(model.status)")
        throw CancellationError()
    }

    @MainActor
    func testRejectedEntitlementsCannotCreatePlayerAndRenewalRecovers() async throws {
        let name = "entitlement-player-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        for outcome in [MockPlaybackEntitlementProvider.Outcome.expired, .keyUnavailable, .denied, .renewalFailed] {
            let provider = MockPlaybackEntitlementProvider(outcomes: [outcome])
            let model = PlaybackModel(titleID: title.id, session: session, entitlementProvider: provider)
            model.load(.bundled)
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while ContinuousClock.now < deadline {
                if case .failed = model.status { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            guard case .failed = model.status else { XCTFail("Entitlement must reject before playback"); return }
            XCTAssertNil(model.player)
            XCTAssertFalse(model.canSeek)
            model.retryPlayback()
            try await waitForPlayback(model)
            let count = await provider.requests
            XCTAssertEqual(count, 2)
            model.stop()
        }
    }

    @MainActor
    func testStopDetachesRealPlayerAndClearsSystemMetadata() async throws {
        let name = "playback-lifecycle-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let model = PlaybackModel(titleID: title.id, session: session)
        model.load(.bundled)
        try await waitForPlayback(model)
        let oldPlayer = try XCTUnwrap(model.player)
        model.stop()
        model.stop() // Explicit close followed by onDisappear.
        XCTAssertEqual(oldPlayer.rate, 0)
        XCTAssertNil(oldPlayer.currentItem)
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)
        XCTAssertNil(PlaybackNowPlaying.shared.session?.nowPlayingInfoCenter.nowPlayingInfo)
        XCTAssertNil(PlaybackNowPlaying.shared.session)
    }

    @MainActor
    func testProfileReplacementDuringSeekStopsOldPlayerAndKeepsNewMetadata() async throws {
        let name = "playback-lifecycle-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let oldProfile = ViewerProfile.demo[0], newProfile = ViewerProfile.demo[1]
        let oldTitle = try await repository.home(profile: oldProfile).hero
        let newTitle = try await repository.home(profile: newProfile).hero
        let oldSession = CatalogSession(profile: oldProfile, repository: repository, configuration: (name, defaults))
        let newSession = CatalogSession(profile: newProfile, repository: repository, configuration: (name, defaults))
        defer { oldSession.invalidate(); newSession.invalidate(); defaults.removePersistentDomain(forName: name) }
        let oldModel = PlaybackModel(titleID: oldTitle.id, session: oldSession)
        oldModel.load(.bundled)
        try await waitForPlayback(oldModel)
        let oldPlayer = try XCTUnwrap(oldModel.player)
        oldModel.seek(to: 10)
        XCTAssertTrue(oldModel.isSeeking)
        // Invalidate before the asynchronous seek callback can publish into the old profile.
        oldSession.invalidate()
        XCTAssertFalse(oldSession.isActive)
        XCTAssertEqual(oldPlayer.rate, 0)
        XCTAssertNil(oldPlayer.currentItem)
        XCTAssertNil(PlaybackNowPlaying.shared.session?.nowPlayingInfoCenter.nowPlayingInfo)
        let newModel = PlaybackModel(titleID: newTitle.id, session: newSession)
        newModel.load(.bundled)
        try await waitForPlayback(newModel)
        oldModel.stop() // A delayed disappearance from the previous SwiftUI subtree.
        oldModel.load(.bundled) // An inactive profile cannot restart playback.
        oldModel.togglePlayback()
        XCTAssertNil(oldModel.player)
        XCTAssertEqual(oldModel.status, .idle)
        XCTAssertEqual(PlaybackNowPlaying.shared.session?.nowPlayingInfoCenter.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, newTitle.name)
        XCTAssertTrue((newModel.player?.rate ?? 0) > 0)
        XCTAssertTrue(PlaybackNowPlaying.shared.session!.remoteCommandCenter.playCommand.isEnabled)
    }

    @MainActor
    func testTenBackgroundCyclesWithCachePressureReleasePlayer() async throws {
        let name = "f05-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        var model: PlaybackModel? = PlaybackModel(titleID: title.id, session: session)
        model?.load(.bundled)
        try await waitForPlayback(try XCTUnwrap(model))
        let releasedModel = PlaybackWeakReference(model)
        let releasedPlayer = PlaybackWeakReference(model?.player)
        let artworkURL = try XCTUnwrap(StreamLabTheme.bundledArtworkURL(seed: 0))
        let cache = ArtworkDataCache(loader: { try Data(contentsOf: $0) })
        let pipeline = ArtworkPipeline(dataCache: cache)
        for _ in 0..<10 {
            _ = try await pipeline.image(for: artworkURL)
            model?.setForeground(false)
            await pipeline.releaseMemory()
            let bytes = await pipeline.cachedDecodedBytes
            XCTAssertEqual(bytes, 0)
            model?.setForeground(true)
            try await waitForPlayback(try XCTUnwrap(model))
            XCTAssertTrue(model?.player === releasedPlayer.value)
        }
        model?.stop()
        model = nil
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (releasedModel.value != nil || releasedPlayer.value != nil), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNil(releasedModel.value)
        XCTAssertNil(releasedPlayer.value)
        XCTAssertNil(PlaybackNowPlaying.shared.session)
    }

    @MainActor
    func testInvalidationBeforeLoadTaskRunsCannotCreatePlayer() async throws {
        let name = "playback-lifecycle-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let model = PlaybackModel(titleID: title.id, session: session)
        model.load(.bundled)
        // No await between load and invalidation: its MainActor load task is queued.
        session.invalidate(saveProgress: false)
        // Yield an actor turn; the cancelled load and all reload requests must stay inert.
        await Task { @MainActor in }.value
        XCTAssertFalse(session.isActive)
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)
        XCTAssertNil(PlaybackNowPlaying.shared.session?.nowPlayingInfoCenter.nowPlayingInfo)
        model.load(.bundled)
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)
    }
}
