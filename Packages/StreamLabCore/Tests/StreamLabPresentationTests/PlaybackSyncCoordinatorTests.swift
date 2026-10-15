import Testing
import StreamLabDomain
import StreamLabCatalogData
import StreamLabPresentation

@Suite("A3 playback adapter") @MainActor
struct PlaybackSyncCoordinatorTests {
    let key = ProgressIdentity(profileID: "adult-a", titleID: "title", sourceID: "episode")

    @Test func closeWriteCompletesBeforeNextDeviceOpens() async {
        let coordinator = PlaybackSyncCoordinator(server: MockProgressServer())
        let a = await coordinator.open(identity: key, deviceID: "A")
        coordinator.submit(.checkpoint(1540), to: a)
        let b = await coordinator.open(identity: key, deviceID: "B")
        #expect(b.snapshot.position == 1540)
    }

    @Test func restartFollowsQueuedCheckpointsAndPersistsZero() async {
        let coordinator = PlaybackSyncCoordinator(server: MockProgressServer())
        let a = await coordinator.open(identity: key, deviceID: "A")
        coordinator.submit(.checkpoint(100), to: a)
        coordinator.submit(.checkpoint(1540), to: a)
        let reset = coordinator.submit(.restart, to: a)
        let reply = await reset.value
        #expect(reply?.snapshot == ProgressSnapshot(revision: 3, position: 0))
        let b = await coordinator.open(identity: key, deviceID: "B")
        #expect(b.snapshot.position == 0)
    }

    @Test func conflictedPlaybackCannotRebaseLaterCheckpoints() async {
        let coordinator = PlaybackSyncCoordinator(server: MockProgressServer())
        let a = await coordinator.open(identity: key, deviceID: "A")
        let b = await coordinator.open(identity: key, deviceID: "B")
        _ = await coordinator.submit(.checkpoint(1540), to: a).value
        let stale = await coordinator.submit(.checkpoint(10), to: b).value
        #expect(stale?.accepted == false)
        #expect(b.conflicted)
        let later = await coordinator.submit(.checkpoint(20), to: b).value
        #expect(later == nil)
        let fresh = await coordinator.open(identity: key, deviceID: "B")
        #expect(fresh.snapshot.position == 1540)
    }
}
