import Foundation

public enum AuthenticationError: Error, Equatable {
    case invalidCredential, invalidated, refreshFailed, refreshTimedOut, unauthorized, invalidOrigin
}

/// One instance per signed-in account session. Create a new instance after explicit sign-in.
/// Tokens are memory-only here; Keychain persistence is a separate integration boundary.
public actor AuthenticationSession {
    public typealias Refresh = @Sendable () async throws -> String
    public typealias Deadline = @Sendable () async throws -> Void
    struct Lease: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        let version: UUID
        let token: String
        var description: String { "AuthenticationLease(redacted)" }
        var debugDescription: String { description }
    }
    private var lease: Lease
    private var active = true
    private var failure: AuthenticationError?
    private let refreshOperation: Refresh
    private let deadline: Deadline
    private var flightID: UUID?
    private var refreshTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var waiters: [UUID: CheckedContinuation<Lease, any Error>] = [:]
    // Internal observation for deterministic concurrency tests; contains no credentials.
    var waitingCount: Int { waiters.count }

    public init(token: String, refresh: @escaping Refresh,
                deadline: @escaping Deadline = { try await Task.sleep(for: .seconds(15)) }) throws {
        guard Self.valid(token) else { throw AuthenticationError.invalidCredential }
        lease = Lease(version: UUID(), token: token)
        refreshOperation = refresh
        self.deadline = deadline
    }

    private static func valid(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                || [45, 46, 95, 126, 43, 47, 61].contains($0)
        }
    }

    func current() throws -> Lease {
        try Task.checkCancellation()
        guard active else { throw AuthenticationError.invalidated }
        if let failure { throw failure }
        return lease
    }

    func checkActive() throws {
        try Task.checkCancellation()
        guard active else { throw AuthenticationError.invalidated }
    }

    func refreshed(after rejected: Lease) async throws -> Lease {
        let current = try current()
        // A delayed 401 from the previous token uses the already-refreshed token.
        if current.version != rejected.version { return current }
        let waiterID = UUID()
        let value = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Lease, any Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                waiters[waiterID] = continuation
                if flightID == nil { startRefresh() }
            }
        } onCancel: {
            Task { await self.cancelWaiter(waiterID) }
        }
        try checkActive()
        return value
    }

    private func startRefresh() {
        let id = UUID(); flightID = id
        let operation = refreshOperation
        refreshTask = Task.detached { [weak self] in
            let result: Result<String, AuthenticationError>
            do {
                let token = try await operation()
                result = Self.valid(token) ? .success(token) : .failure(.invalidCredential)
            } catch { result = .failure(.refreshFailed) }
            await self?.complete(id, result: result)
        }
        let wait = deadline
        deadlineTask = Task.detached { [weak self] in
            do { try await wait() } catch {
                guard !Task.isCancelled else { return }
            }
            guard !Task.isCancelled else { return }
            await self?.complete(id, result: .failure(.refreshTimedOut))
        }
    }

    private func complete(_ id: UUID, result: Result<String, AuthenticationError>) {
        guard active, flightID == id else { return }
        flightID = nil
        refreshTask?.cancel(); refreshTask = nil
        deadlineTask?.cancel(); deadlineTask = nil
        let callbacks = Array(waiters.values); waiters.removeAll()
        switch result {
        case .success(let token):
            lease = Lease(version: UUID(), token: token)
            for callback in callbacks { callback.resume(returning: lease) }
        case .failure(let error):
            // Latch the failed session so late 401s cannot start a refresh storm.
            failure = error
            for callback in callbacks { callback.resume(throwing: error) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
        // Other requests still share the refresh. Even with no waiters it has a bounded deadline.
    }

    func reject(_ rejected: Lease) {
        if lease.version == rejected.version { failure = .unauthorized }
    }

    public func invalidate() {
        active = false; flightID = nil
        refreshTask?.cancel(); refreshTask = nil
        deadlineTask?.cancel(); deadlineTask = nil
        lease = Lease(version: UUID(), token: "")
        let callbacks = Array(waiters.values); waiters.removeAll()
        for callback in callbacks { callback.resume(throwing: AuthenticationError.invalidated) }
    }
}
