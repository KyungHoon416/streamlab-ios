import AVFoundation
import Combine
import Foundation
import MediaPlayer
import StreamLabCatalogData
import StreamLabDomain
import StreamLabPresentation
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackEntitlementBoundaryTests: XCTestCase {
    private actor HeldEntitlement: PlaybackEntitlementProvider {
        private var reply: CheckedContinuation<PlaybackEntitlement, Never>?
        private var scope: PlaybackEntitlementScope?
        var pending: Bool { reply != nil }
        func entitlement(for scope: PlaybackEntitlementScope) async throws -> PlaybackEntitlement {
            self.scope = scope
            // Deliberately ignores cancellation, like an already dispatched server reply.
            return await withCheckedContinuation { reply = $0 }
        }
        func release() {
            guard let scope, let reply else { return }
            self.reply = nil
            reply.resume(returning: PlaybackEntitlement(scope: scope, allowed: true, keyState: .usable,
                issuedAt: Date().addingTimeInterval(-1), expiresAt: Date().addingTimeInterval(300)))
        }
    }

    @MainActor
    private func waitUntil(_ predicate: @MainActor () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Expected playback boundary state was not reached")
        throw CancellationError()
    }

    @MainActor
    private func exerciseLateReply(invalidate: Bool, replaceProfile: Bool) async throws {
        let name = "entitlement-boundary-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        let provider = HeldEntitlement()
        let model = PlaybackModel(titleID: title.id, session: session, entitlementProvider: provider)
        defer {
            session.invalidate()
            defaults.removePersistentDomain(forName: name)
            Task { await provider.release() }
        }
        model.load(.bundled)
        try await waitUntil { await provider.pending }
        if invalidate { session.invalidate(saveProgress: false) } else { model.stop() }
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)

        var replacement: PlaybackModel?
        var replacementSession: CatalogSession?
        if replaceProfile {
            let other = ViewerProfile.demo[1]
            let otherTitle = try await repository.home(profile: other).hero
            let next = CatalogSession(profile: other, repository: repository, configuration: (name, defaults))
            replacementSession = next
            replacement = PlaybackModel(titleID: otherTitle.id, session: next)
            replacement?.load(.bundled)
            try await waitUntil { replacement?.status == .playing && (replacement?.player?.rate ?? 0) > 0 }
        }
        defer { replacementSession?.invalidate() }
        let currentSession = PlaybackNowPlaying.shared.session
        let resurrected = expectation(description: "Late success must not resurrect the old player")
        resurrected.isInverted = true
        let observation = model.$player.sink { if $0 != nil { resurrected.fulfill() } }
        await provider.release()
        // Bounded observation after the deliberately late reply, not just an immediate nil check.
        let result = await XCTWaiter.fulfillment(of: [resurrected], timeout: 0.5)
        XCTAssertEqual(result, .completed)
        withExtendedLifetime(observation) {}
        XCTAssertNil(model.player)
        XCTAssertEqual(model.status, .idle)
        XCTAssertTrue(PlaybackNowPlaying.shared.session === currentSession)
        if let replacement {
            XCTAssertEqual(replacement.status, .playing)
            XCTAssertTrue((replacement.player?.rate ?? 0) > 0)
        }
    }

    @MainActor func testCloseRejectsLateEntitlementSuccess() async throws {
        try await exerciseLateReply(invalidate: false, replaceProfile: false)
    }
    @MainActor func testInvalidatedSessionRejectsLateEntitlementSuccess() async throws {
        try await exerciseLateReply(invalidate: true, replaceProfile: false)
    }
    @MainActor func testOldProfileReplyCannotReplaceNewPlayer() async throws {
        try await exerciseLateReply(invalidate: true, replaceProfile: true)
    }

    @MainActor func testDownloadedSourceExpiredGrantAndOfflineRenewalNeverCreatePlayer() async throws {
        let name = "f09-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let provider = MockPlaybackEntitlementProvider(outcomes: [.expired], fallback: .renewalFailed)
        let model = PlaybackModel(titleID: title.id, session: session, entitlementProvider: provider)
        model.load(.downloadedHLS)
        for remaining in stride(from: 3, through: 0, by: -1) {
            try await waitUntil { model.failureIsEntitlement }
            XCTAssertNil(model.player)
            XCTAssertNil(PlaybackNowPlaying.shared.session)
            XCTAssertEqual(model.retryBudget.remaining, remaining)
            XCTAssertEqual(model.source, .downloadedHLS)
            XCTAssertTrue(model.status.label.contains(remaining == 3 ? "권한이 만료" : "권한을 갱신하지 못했습니다"))
            if remaining > 0 { model.retryPlayback() }
        }
        model.retryPlayback()
        let count = await provider.requests
        XCTAssertEqual(count, 4)
        model.stop()
        XCTAssertEqual(model.status, .idle)
    }

    @MainActor func testPersistentRenewalFailureExhaustsRetryBudget() async throws {
        let name = "entitlement-retry-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let repository = MockCatalogRepository(responseDelay: .zero)
        let profile = ViewerProfile.demo[0]
        let title = try await repository.home(profile: profile).hero
        let session = CatalogSession(profile: profile, repository: repository, configuration: (name, defaults))
        defer { session.invalidate(); defaults.removePersistentDomain(forName: name) }
        let provider = MockPlaybackEntitlementProvider(fallback: .renewalFailed)
        let model = PlaybackModel(titleID: title.id, session: session, entitlementProvider: provider)
        model.load(.bundled)
        for remaining in stride(from: 3, through: 0, by: -1) {
            try await waitUntil { if case .failed = model.status { return true }; return false }
            XCTAssertNil(model.player)
            XCTAssertEqual(model.retryBudget.remaining, remaining)
            XCTAssertEqual(model.canRetryPlayback, remaining > 0)
            if remaining > 0 { model.retryPlayback() }
        }
        let before = await provider.requests
        XCTAssertEqual(before, 4)
        for _ in 0..<10 { model.retryPlayback() }
        await Task { @MainActor in }.value
        let after = await provider.requests
        XCTAssertEqual(after, before)
        XCTAssertNil(model.player)
    }
}
