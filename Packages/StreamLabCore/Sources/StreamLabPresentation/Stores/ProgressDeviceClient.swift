import StreamLabDomain

/// One simulated device, permanently scoped to a profile/content/source identity.
/// Conflicts refresh the local view, but NEVER rebase an old playback event and resend it.
public actor ProgressDeviceClient {
    private let server: any ProgressServer
    private let identity: ProgressIdentity
    private let deviceID: String
    public private(set) var snapshot = ProgressSnapshot()

    public init(server: any ProgressServer, identity: ProgressIdentity, deviceID: String) {
        self.server = server; self.identity = identity; self.deviceID = deviceID
    }

    @discardableResult public func refresh() async -> ProgressSnapshot {
        merge(await server.fetch(identity))
        return snapshot
    }

    /// Capture the revision when the event is created, not when it is finally sent.
    public func command(_ mutation: ProgressMutation) -> ProgressCommand {
        ProgressCommand(identity: identity, deviceID: deviceID,
                        baseRevision: snapshot.revision, mutation: mutation)
    }

    @discardableResult public func send(_ command: ProgressCommand) async throws -> ProgressReply {
        // A caller cannot use this scoped client to submit another profile/device's event.
        guard command.identity == identity, command.deviceID == deviceID else {
            throw ProgressDeviceError.identityMismatch
        }
        let reply = try await server.apply(command)
        merge(reply.snapshot)
        return reply
    }

    private func merge(_ incoming: ProgressSnapshot) {
        guard incoming.revision >= snapshot.revision else { return }
        snapshot = incoming
    }
}

public enum ProgressDeviceError: Error, Sendable { case identityMismatch }
