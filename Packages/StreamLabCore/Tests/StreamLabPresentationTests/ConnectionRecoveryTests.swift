import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation
import StreamLabCatalogData

@Suite("B2 connection recovery scheduling")
@MainActor struct ConnectionRecoveryTests {
    @MainActor final class Probe {
        var calls = 0
        var blockFirst = false
        var blocked: CheckedContinuation<Void, Never>?
        var started: CheckedContinuation<Void, Never>?
        func run() async {
            calls += 1
            if blockFirst, calls == 1 {
                await withCheckedContinuation { continuation in
                    blocked = continuation
                    started?.resume(); started = nil
                }
            }
        }
        func waitUntilBlocked() async {
            if blocked != nil { return }
            await withCheckedContinuation { started = $0 }
        }
        func release() { blocked?.resume(); blocked = nil }
    }

    @Test func duplicateOnlineSignalsDoNotRetryContinuously() async {
        let probe = Probe()
        let recovery = ConnectionRecoveryCoordinator { await probe.run() }
        recovery.update(isAvailable: false)
        await recovery.waitForIdle()
        #expect(probe.calls == 0)
        for _ in 0..<20 { recovery.update(isAvailable: true) }
        await recovery.waitForIdle()
        recovery.update(isAvailable: true)
        await recovery.waitForIdle()
        #expect(probe.calls == 1)
    }

    @Test func reconnectDuringSendCoalescesIntoOneFollowUp() async {
        let probe = Probe(); probe.blockFirst = true
        let recovery = ConnectionRecoveryCoordinator { await probe.run() }
        recovery.update(isAvailable: true)
        await probe.waitUntilBlocked()
        for _ in 0..<10 {
            recovery.update(isAvailable: false)
            recovery.update(isAvailable: true)
        }
        #expect(probe.calls == 1)
        probe.release()
        await recovery.waitForIdle()
        #expect(probe.calls == 2)
    }

    @Test func offlineBeforeFollowUpSuppressesRetry() async {
        let probe = Probe(); probe.blockFirst = true
        let recovery = ConnectionRecoveryCoordinator { await probe.run() }
        recovery.update(isAvailable: true)
        await probe.waitUntilBlocked()
        recovery.update(isAvailable: false)
        recovery.update(isAvailable: true)
        recovery.update(isAvailable: false)
        probe.release()
        await recovery.waitForIdle()
        #expect(probe.calls == 1)
        recovery.update(isAvailable: true)
        await recovery.waitForIdle()
        #expect(probe.calls == 2)
    }

    @Test func suspensionRejectsLateEventsAndQueuedFollowUp() async {
        let probe = Probe(); probe.blockFirst = true
        let recovery = ConnectionRecoveryCoordinator { await probe.run() }
        recovery.update(isAvailable: true)
        await probe.waitUntilBlocked()
        recovery.update(isAvailable: false)
        recovery.update(isAvailable: true)
        recovery.suspend()
        recovery.update(isAvailable: true)
        probe.release()
        await recovery.waitForIdle()
        #expect(probe.calls == 1)
    }

    @Test func foregroundCanRetryWithoutNewOfflineSignal() async {
        let probe = Probe()
        let recovery = ConnectionRecoveryCoordinator { await probe.run() }
        recovery.update(isAvailable: true)
        await recovery.waitForIdle()
        recovery.suspend(); recovery.resume()
        recovery.update(isAvailable: true)
        await recovery.waitForIdle()
        #expect(probe.calls == 2)
    }

    struct Offline: MutationTransport {
        func send(_ mutation: DurableMutation) async throws -> UInt64 {
            throw URLError(.notConnectedToInternet)
        }
    }
    @Test func recoveryDrainsPreviouslyFailedDurableRequest() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let scope = MutationScope(accountID: "recovery", profileID: "a")
        let queue = try DurableMutationStore(directory: dir, scope: scope)
        try queue.set(Data([1]), forKey: "test")
        let original = queue.pending
        do { try await queue.flush(using: Offline()); Issue.record("Expected offline error") }
        catch { }
        #expect(queue.pending == original)
        let server = MockMutationServer()
        let recovery = ConnectionRecoveryCoordinator {
            do { try await queue.flush(using: server) }
            catch { Issue.record("Unexpected recovery failure: \(error)") }
        }
        recovery.update(isAvailable: false)
        recovery.update(isAvailable: true)
        await recovery.waitForIdle()
        #expect(queue.pending.isEmpty)
        #expect(await server.revision(for: scope) == 1)
        #expect(await server.values(for: scope)["test"] == Data([1]))
    }
}
