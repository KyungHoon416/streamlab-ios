import Foundation
import Testing
import StreamLabDomain
import StreamLabCatalogData
import StreamLabPresentation

@Suite("A3 multi-device revision simulation")
struct ProgressSyncTests {
    private let key = ProgressIdentity(profileID: "adult-a", titleID: "title-1", sourceID: "episode-1")

    @Test func deviceBRestoresTwentyFiveMinutesFortySeconds() async throws {
        let server = MockProgressServer()
        let a = ProgressDeviceClient(server: server, identity: key, deviceID: "A")
        let b = ProgressDeviceClient(server: server, identity: key, deviceID: "B")
        let event = await a.command(.checkpoint(1540))
        let reply = try await a.send(event)
        #expect(reply.accepted)
        let restored = await b.refresh()
        #expect(restored == ProgressSnapshot(revision: 1, position: 1540))
    }

    @Test func delayedOldEventCannotOverwriteNewProgress() async throws {
        let server = MockProgressServer()
        let a = ProgressDeviceClient(server: server, identity: key, deviceID: "A")
        let old = await a.command(.checkpoint(20))
        let newer = await a.command(.checkpoint(1540))
        _ = try await a.send(newer)
        let reply = try await a.send(old)
        #expect(!reply.accepted)
        let state = await server.fetch(key)
        #expect(state.position == 1540)
        #expect(state.revision == 1)
    }

    @Test func restartRejectsDelayedPreRestartProgressAndAllowsNewViewing() async throws {
        let server = MockProgressServer()
        let a = ProgressDeviceClient(server: server, identity: key, deviceID: "A")
        let b = ProgressDeviceClient(server: server, identity: key, deviceID: "B")
        _ = try await a.send(a.command(.checkpoint(1540)))
        _ = await b.refresh()
        let delayed = await a.command(.checkpoint(1600))
        let restart = try await b.send(b.command(.restart))
        #expect(restart.snapshot == ProgressSnapshot(revision: 2, position: 0))
        let rejected = try await a.send(delayed)
        #expect(!rejected.accepted)
        #expect(rejected.snapshot.position == 0)
        let fresh = try await b.send(b.command(.checkpoint(10)))
        #expect(fresh.snapshot == ProgressSnapshot(revision: 3, position: 10))
    }

    @Test func duplicateReceiptCannotRollBackClientAfterRestart() async throws {
        let server = MockProgressServer()
        let a = ProgressDeviceClient(server: server, identity: key, deviceID: "A")
        let old = await a.command(.checkpoint(1540))
        let original = try await a.send(old)
        _ = try await a.send(a.command(.restart))
        let duplicate = try await a.send(old)
        #expect(duplicate == original)
        let local = await a.snapshot
        let remote = await server.fetch(key)
        #expect(local == ProgressSnapshot(revision: 2, position: 0))
        #expect(remote == local)
    }

    @Test func simultaneousWritersHaveExactlyOneWinner() async throws {
        let server = MockProgressServer()
        let a = ProgressCommand(identity: key, deviceID: "A", baseRevision: 0, mutation: .checkpoint(100))
        let b = ProgressCommand(identity: key, deviceID: "B", baseRevision: 0, mutation: .checkpoint(200))
        async let first = server.apply(a)
        async let second = server.apply(b)
        let replies = try await [first, second]
        #expect(replies.filter(\.accepted).count == 1)
        let final = await server.fetch(key)
        #expect(final.revision == 1)
        #expect(final.position == 100 || final.position == 200)
    }

    @Test func profilesTitlesAndEpisodesRemainIsolated() async throws {
        let server = MockProgressServer()
        _ = try await server.apply(ProgressCommand(identity: key, deviceID: "A", baseRevision: 0, mutation: .checkpoint(1540)))
        for other in [
            ProgressIdentity(profileID: "adult-b", titleID: "title-1", sourceID: "episode-1"),
            ProgressIdentity(profileID: "adult-a", titleID: "title-2", sourceID: "episode-1"),
            ProgressIdentity(profileID: "adult-a", titleID: "title-1", sourceID: "episode-2")
        ] {
            let value = await server.fetch(other)
            #expect(value == ProgressSnapshot())
        }
    }

    @Test func invalidPositionsAndReusedIDsDoNotMutateServer() async throws {
        let server = MockProgressServer()
        for value in [Double.nan, .infinity, -1] {
            do {
                _ = try await server.apply(ProgressCommand(identity: key, deviceID: "A", baseRevision: 0, mutation: .checkpoint(value)))
                Issue.record("Invalid position was accepted")
            } catch { #expect(error as? ProgressSyncError == .invalidPosition) }
        }
        let id = UUID()
        _ = try await server.apply(ProgressCommand(id: id, identity: key, deviceID: "A", baseRevision: 0, mutation: .checkpoint(1540)))
        do {
            _ = try await server.apply(ProgressCommand(id: id, identity: key, deviceID: "A", baseRevision: 1, mutation: .restart))
            Issue.record("Reused ID with changed payload was accepted")
        } catch { #expect(error as? ProgressSyncError == .reusedCommandID) }
        let value = await server.fetch(key)
        #expect(value == ProgressSnapshot(revision: 1, position: 1540))
    }

    @Test func staleRestartRequiresFreshExplicitUserCommand() async throws {
        let server = MockProgressServer()
        let a = ProgressDeviceClient(server: server, identity: key, deviceID: "A")
        let b = ProgressDeviceClient(server: server, identity: key, deviceID: "B")
        let staleRestart = await b.command(.restart)
        _ = try await a.send(a.command(.checkpoint(1540)))
        let conflict = try await b.send(staleRestart)
        #expect(!conflict.accepted)
        #expect(conflict.snapshot.position == 1540)
        let explicitRetry = try await b.send(b.command(.restart))
        #expect(explicitRetry.accepted)
        #expect(explicitRetry.snapshot == ProgressSnapshot(revision: 2, position: 0))
    }
}
