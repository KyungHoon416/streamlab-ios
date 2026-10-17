import AVFoundation
import Foundation
import MediaPlayer
import StreamLabCatalogData
import StreamLabDomain
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackSessionLifecycleTests: XCTestCase {
    @MainActor
    private func waitForPlayback(_ model: PlaybackModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while ContinuousClock.now < deadline {
            if model.status == .playing, (model.player?.rate ?? 0) > 0,
               MPNowPlayingInfoCenter.default().nowPlayingInfo != nil { return }
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
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertFalse(MPRemoteCommandCenter.shared().playCommand.isEnabled)
    }

    @MainActor
    func testProfileReplacementStopsOldPlayerAndKeepsNewMetadata() async throws {
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
        oldSession.invalidate()
        XCTAssertFalse(oldSession.isActive)
        XCTAssertEqual(oldPlayer.rate, 0)
        XCTAssertNil(oldPlayer.currentItem)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        let newModel = PlaybackModel(titleID: newTitle.id, session: newSession)
        newModel.load(.bundled)
        try await waitForPlayback(newModel)
        oldModel.stop() // A delayed disappearance from the previous SwiftUI subtree.
        oldModel.load(.bundled) // An inactive profile cannot restart playback.
        oldModel.togglePlayback()
        XCTAssertNil(oldModel.player)
        XCTAssertEqual(oldModel.status, .idle)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, newTitle.name)
        XCTAssertTrue((newModel.player?.rate ?? 0) > 0)
        XCTAssertTrue(MPRemoteCommandCenter.shared().playCommand.isEnabled)
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
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        model.load(.bundled)
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)
    }
}
