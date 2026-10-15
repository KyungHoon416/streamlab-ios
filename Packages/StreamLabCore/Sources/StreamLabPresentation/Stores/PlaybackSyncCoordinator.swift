import StreamLabDomain

/// FIFO adapter for a single app's simulated devices. A new playback waits for prior close saves.
@MainActor public final class PlaybackSyncCoordinator {
    private let server: any ProgressServer
    private var tail: Task<ProgressReply?, Never>?
    public init(server: any ProgressServer) { self.server = server }

    public func open(identity: ProgressIdentity, deviceID: String) async -> SyncedPlaybackProgress {
        let pending = tail
        _ = await pending?.value
        let snapshot = await server.fetch(identity)
        return SyncedPlaybackProgress(server: server, identity: identity, deviceID: deviceID, snapshot: snapshot)
    }

    @discardableResult public func submit(_ mutation: ProgressMutation, to session: SyncedPlaybackProgress) -> Task<ProgressReply?, Never> {
        let previous = tail
        let task = Task { @MainActor in
            _ = await previous?.value
            return await session.apply(mutation)
        }
        tail = task
        return task
    }
}

@MainActor public final class SyncedPlaybackProgress {
    private let server: any ProgressServer
    private let identity: ProgressIdentity
    private let deviceID: String
    public private(set) var snapshot: ProgressSnapshot
    public private(set) var conflicted = false
    fileprivate init(server: any ProgressServer, identity: ProgressIdentity, deviceID: String, snapshot: ProgressSnapshot) {
        self.server = server; self.identity = identity; self.deviceID = deviceID; self.snapshot = snapshot
    }
    fileprivate func apply(_ mutation: ProgressMutation) async -> ProgressReply? {
        // Do not rebase old playback events after another device changed the server.
        guard !conflicted else { return nil }
        let command = ProgressCommand(identity: identity, deviceID: deviceID,
                                      baseRevision: snapshot.revision, mutation: mutation)
        do {
            let reply = try await server.apply(command)
            if reply.snapshot.revision >= snapshot.revision { snapshot = reply.snapshot }
            if !reply.accepted { conflicted = true }
            return reply
        } catch {
            conflicted = true
            return nil
        }
    }
}
