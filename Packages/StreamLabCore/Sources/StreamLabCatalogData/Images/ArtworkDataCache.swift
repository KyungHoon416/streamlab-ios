import Foundation

public enum ArtworkLoadError: Error, Sendable { case invalidResponse, tooLarge, unsupportedURL }

/// Byte-bounded LRU and shared in-flight requests. Cancelling one subscriber does not cancel others.
public actor ArtworkDataCache {
    public typealias Loader = @Sendable (URL) async throws -> Data
    private struct Pending {
        let generation: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<Data, any Error>]
    }
    private let loader: Loader
    private let byteLimit: Int
    private let itemLimit: Int
    private var cache: [URL: Data] = [:]
    private var order: [URL] = []
    private var bytes = 0
    private var pending: [URL: Pending] = [:]

    public init(byteLimit: Int = 16 * 1024 * 1024, itemLimit: Int = 8 * 1024 * 1024,
                loader: @escaping Loader) {
        self.byteLimit = max(0, byteLimit); self.itemLimit = max(0, itemLimit); self.loader = loader
    }

    public func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        if let hit = cache[url] {
            touch(url)
            return hit
        }
        let waiter = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                if var request = pending[url] {
                    request.waiters[waiter] = continuation
                    pending[url] = request
                } else {
                    let generation = UUID()
                    let loader = loader
                    let task = Task { [weak self] in
                        let result: Result<Data, any Error>
                        do { result = .success(try await loader(url)) }
                        catch { result = .failure(error) }
                        await self?.finish(url, generation: generation, result: result)
                    }
                    pending[url] = Pending(generation: generation, task: task, waiters: [waiter: continuation])
                }
            }
        } onCancel: {
            Task { await self.cancel(url, waiter: waiter) }
        }
    }

    private func cancel(_ url: URL, waiter: UUID) {
        guard var request = pending[url], let continuation = request.waiters.removeValue(forKey: waiter) else { return }
        if request.waiters.isEmpty {
            pending.removeValue(forKey: url)
            request.task.cancel()
        } else { pending[url] = request }
        continuation.resume(throwing: CancellationError())
    }

    private func finish(_ url: URL, generation: UUID, result: Result<Data, any Error>) {
        guard let request = pending[url], request.generation == generation else { return }
        pending.removeValue(forKey: url)
        let checked = result.flatMap { data -> Result<Data, any Error> in
            guard !data.isEmpty else { return .failure(ArtworkLoadError.invalidResponse) }
            guard data.count <= itemLimit else { return .failure(ArtworkLoadError.tooLarge) }
            return .success(data)
        }
        if case .success(let data) = checked, data.count <= byteLimit {
            cache[url] = data; bytes += data.count; touch(url)
            while bytes > byteLimit, let oldest = order.first {
                order.removeFirst()
                bytes -= cache.removeValue(forKey: oldest)?.count ?? 0
            }
        }
        for continuation in request.waiters.values { continuation.resume(with: checked) }
    }

    private func touch(_ url: URL) { order.removeAll { $0 == url }; order.append(url) }
    public func removeCachedData() { cache.removeAll(); order.removeAll(); bytes = 0 }
    public var cachedByteCount: Int { bytes }
    public var subscriberCount: Int { pending.values.reduce(0) { $0 + $1.waiters.count } }
}
