import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation

@Suite("B2 virtual clock retry chaos")
struct RetryClockChaosTests {
    /// Manual time: sleep cannot finish until advance reaches its deadline.
    /// Deliberately ignores cancellation so the adapter must check it after waking.
    actor Clock {
        var now: Double = 0
        var durations: [Double] = []
        var deadline: Double?
        var sleeper: CheckedContinuation<Void, Never>?
        var observer: CheckedContinuation<Double, Never>?
        func sleep(_ duration: Double) async {
            await withCheckedContinuation { continuation in
                durations.append(duration)
                deadline = now + duration
                sleeper = continuation
                observer?.resume(returning: duration); observer = nil
            }
        }
        func waitForSleep(_ index: Int) async -> Double {
            if durations.count > index { return durations[index] }
            return await withCheckedContinuation { observer = $0 }
        }
        func advance(by amount: Double) {
            now += amount
            if let deadline, now >= deadline {
                self.deadline = nil
                sleeper?.resume(); sleeper = nil
            }
        }
    }

    @Test(.timeLimit(.minutes(2))) @MainActor func thousandRetrySchedulesRespectDeadlinesAndCancellation() async throws {
        let replay = ProcessInfo.processInfo.environment["STREAMLAB_CHAOS_SEED"]
        let seeds: [UInt64]
        if let replay { seeds = [try #require(UInt64(replay), "Invalid chaos seed")] }
        else { seeds = Array(1...1000).map(UInt64.init) }
        for seed in seeds {
            var random = MutationChaosTests.Generator(state: seed)
            let sample = Double(random.next()) / 7
            let cancelAt = random.next() % 4 // 0...2 cancels in backoff; 3 reaches success.
            var failures: [any Error & Sendable] = []
            var minimums: [Double] = []
            var codes: [Int] = []
            for _ in 0..<3 {
                let code = random.next() % 3
                let minimum = code == 2 ? 0 : Double(random.next()) * 2
                minimums.append(minimum); codes.append(code)
                switch code {
                case 0: failures.append(MutationHTTPError.status(429, retryAfter: minimum))
                case 1: failures.append(MutationHTTPError.status(503, retryAfter: minimum))
                default: failures.append(URLError(.timedOut))
                }
            }
            do { try await run(seed: seed, sample: sample, cancelAt: cancelAt, failures: failures, minimums: minimums) }
            catch {
                Issue.record("Retry seed=\(seed) jitter=\(sample) cancelAt=\(cancelAt) codes=\(codes) RetryAfter=\(minimums) error=\(error)")
                throw error
            }
        }
        print("RETRY CLOCK CHAOS PASS seeds=\(seeds.count) replay=\(replay ?? "1...1000")")
    }

    private func run(seed: UInt64, sample: Double, cancelAt: Int, failures: [any Error & Sendable],
                     minimums: [Double]) async throws {
        let clock = Clock()
        let probe = MutationRetryTests.Probe(failures)
        let envelope = DurableMutation(id: UUID(), scope: MutationScope(accountID: "clock", profileID: "a"),
            deviceID: UUID(), sequence: 1, baseRevision: 0, key: "key", value: Data([1]))
        let transport = RetryingMutationTransport(base: probe, sleep: { await clock.sleep($0) }, random: { sample })
        let task = Task { try await transport.send(envelope) }
        for index in 0..<3 {
            let duration = await clock.waitForSleep(index)
            // Check before advancing; a delay violation must not silently pass.
            let expected = max(minimums[index], [1.0, 2.0, 4.0][index] * (0.5 + sample * 0.5))
            #expect(abs(duration - expected) < 0.000001, "seed=\(seed) sleep=\(index)")
            #expect(await probe.requests.count == index + 1, "seed=\(seed) sleep=\(index)")
            await clock.advance(by: duration / 2)
            #expect(await probe.requests.count == index + 1, "seed=\(seed): no send before virtual deadline")
            if index == cancelAt { task.cancel() }
            // A tiny epsilon avoids accumulated floating-point rounding at the deadline.
            await clock.advance(by: duration / 2 + 0.000001)
            if index == cancelAt { break }
        }
        if cancelAt < 3 {
            do { _ = try await task.value; Issue.record("Expected cancellation") }
            catch { try #require(error is CancellationError) }
            try #require(await probe.requests == Array(repeating: envelope, count: cancelAt + 1))
            try #require(await probe.server.revision(for: envelope.scope) == 0)
        } else {
            try #require(try await task.value == 1)
            try #require(await probe.requests == Array(repeating: envelope, count: 4))
            try #require(await probe.server.revision(for: envelope.scope) == 1)
        }
    }
}
