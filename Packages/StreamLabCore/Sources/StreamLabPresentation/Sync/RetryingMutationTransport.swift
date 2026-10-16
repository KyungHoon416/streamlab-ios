import Foundation
import StreamLabDomain

/// A transport adapter maps HTTP status/Retry-After to this error. No credentials or payloads.
public enum MutationHTTPError: Error, Sendable {
    case status(Int, retryAfter: TimeInterval?)
}

/// Finite per-request retry budget; exact immutable envelope on every attempt.
/// 409/401 and unknown errors propagate unchanged. Conflict/auth policies are separate.
public struct RetryingMutationTransport: MutationTransport {
    private let base: any MutationTransport
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let random: @Sendable () -> Double
    public init(base: any MutationTransport,
                sleep: @escaping @Sendable (TimeInterval) async throws -> Void = {
                    try await Task.sleep(for: .seconds($0))
                }, random: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }) {
        self.base = base
        self.sleep = sleep
        self.random = random
    }

    public func send(_ mutation: DurableMutation) async throws -> UInt64 {
        for attempt in 0..<4 {
            try Task.checkCancellation()
            do {
                let revision = try await base.send(mutation)
                try Task.checkCancellation()
                return revision
            } catch {
                try Task.checkCancellation()
                guard attempt < 3, let minimum = Self.retryMinimum(error) else { throw error }
                // Equal jitter: [0.5, 1], [1, 2], [2, 4] seconds.
                let sample = random()
                let jitter = sample.isFinite ? min(1, max(0, sample)) : 0.5
                let ceiling = pow(2.0, Double(attempt))
                let delay = max(minimum, ceiling * (0.5 + jitter * 0.5))
                try await sleep(delay)
                // Includes sleepers that return normally despite cancellation.
                try Task.checkCancellation()
            }
        }
        throw MutationQueueError.invalidReceipt // Unreachable; keeps all paths explicit.
    }

    private static func retryMinimum(_ error: any Error) -> TimeInterval? {
        if let http = error as? MutationHTTPError {
            switch http {
            case let .status(code, retryAfter):
                guard code == 429 || code == 503 else { return nil }
                guard let retryAfter else { return 0 }
                // Never violate a long server delay by clamping it down. Defer to a later sync.
                guard retryAfter.isFinite, retryAfter >= 0, retryAfter <= 30 else { return nil }
                return retryAfter
            }
        }
        if let network = error as? URLError {
            switch network.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return 0
            default: return nil
            }
        }
        return nil
    }
}
