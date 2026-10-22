import Foundation
import Testing
import StreamLabCatalogData

private actor ArtworkGate {
    private var waiting: [CheckedContinuation<Data, any Error>] = []
    func load(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { waiting.append($0) }
    }
    func complete(_ data: Data) { waiting.removeFirst().resume(returning: data) }
    var count: Int { waiting.count }
}
private actor ArtworkCounter {
    var calls = 0
    func load(_ url: URL) -> Data { calls += 1; return Data(repeating: 1, count: 4) }
}

@Suite("Artwork cache and cancellation")
struct ArtworkDataCacheTests {
    let first = URL(string: "https://example.invalid/1.png")!
    let second = URL(string: "https://example.invalid/2.png")!
    let third = URL(string: "https://example.invalid/3.png")!

    private func ready(_ cache: ArtworkDataCache, subscribers: Int, gate: ArtworkGate, loads: Int) async throws {
        for _ in 0..<10000 {
            if await cache.subscriberCount == subscribers, await gate.count == loads { return }
            await Task.yield()
        }
        Issue.record("Requests failed to reach controlled suspension point")
        throw CancellationError()
    }

    @Test func lruEvictsLeastRecentlyUsedWithinByteBudget() async throws {
        let counter = ArtworkCounter()
        let cache = ArtworkDataCache(byteLimit: 8, loader: { await counter.load($0) })
        _ = try await cache.data(for: first)
        _ = try await cache.data(for: second)
        _ = try await cache.data(for: first)
        _ = try await cache.data(for: third)
        #expect(await cache.cachedByteCount == 8)
        #expect(await counter.calls == 3)
        _ = try await cache.data(for: second)
        #expect(await counter.calls == 4)
        await cache.removeCachedData()
        #expect(await cache.cachedByteCount == 0)
    }

    @Test func sameURLSharesOneLoadAndOneCancellationKeepsOtherSubscriber() async throws {
        let gate = ArtworkGate()
        let cache = ArtworkDataCache(loader: { try await gate.load($0) })
        let a = Task { try await cache.data(for: first) }
        let b = Task { try await cache.data(for: first) }
        try await ready(cache, subscribers: 2, gate: gate, loads: 1)
        a.cancel()
        do { _ = try await a.value; Issue.record("Cancelled subscriber returned data") }
        catch { #expect(error is CancellationError) }
        await gate.complete(Data([1, 2, 3]))
        #expect(try await b.value == Data([1, 2, 3]))
        #expect(await cache.subscriberCount == 0)
    }

    @Test func lastCancellationRejectsLateCompletionFromOldGeneration() async throws {
        let gate = ArtworkGate()
        let cache = ArtworkDataCache(loader: { try await gate.load($0) })
        let old = Task { try await cache.data(for: first) }
        try await ready(cache, subscribers: 1, gate: gate, loads: 1)
        old.cancel()
        do { _ = try await old.value; Issue.record("Cancellation ignored") } catch { #expect(error is CancellationError) }
        let current = Task { try await cache.data(for: first) }
        try await ready(cache, subscribers: 1, gate: gate, loads: 2)
        await gate.complete(Data([9])) // loader deliberately ignores cancellation
        await gate.complete(Data([1, 2]))
        #expect(try await current.value == Data([1, 2]))
        #expect(try await cache.data(for: first) == Data([1, 2]))
    }

    @Test func oversizedAndEmptyResultsAreNotCached() async throws {
        let gate = ArtworkGate()
        let cache = ArtworkDataCache(itemLimit: 2, loader: { try await gate.load($0) })
        for data in [Data([1, 2, 3]), Data()] {
            let request = Task { try await cache.data(for: first) }
            try await ready(cache, subscribers: 1, gate: gate, loads: 1)
            await gate.complete(data)
            do { _ = try await request.value; Issue.record("Invalid payload accepted") }
            catch { #expect(error is ArtworkLoadError) }
            #expect(await cache.cachedByteCount == 0)
        }
    }

    @Test func purgeDuringSharedLoadDeliversButDoesNotRepopulateCache() async throws {
        let gate = ArtworkGate()
        let cache = ArtworkDataCache(loader: { try await gate.load($0) })
        let a = Task { try await cache.data(for: first) }
        let b = Task { try await cache.data(for: first) }
        try await ready(cache, subscribers: 2, gate: gate, loads: 1)
        await cache.removeCachedData()
        await gate.complete(Data([1, 2]))
        #expect(try await a.value == Data([1, 2]))
        #expect(try await b.value == Data([1, 2]))
        #expect(await cache.cachedByteCount == 0)
        #expect(await cache.subscriberCount == 0)
        let fresh = Task { try await cache.data(for: first) }
        try await ready(cache, subscribers: 1, gate: gate, loads: 1)
        await gate.complete(Data([3]))
        #expect(try await fresh.value == Data([3]))
        #expect(await cache.cachedByteCount == 1)
    }

    @Test func repeatedPurgeAndReloadStaysBounded() async throws {
        let counter = ArtworkCounter()
        let cache = ArtworkDataCache(loader: { await counter.load($0) })
        for _ in 0..<10 {
            _ = try await cache.data(for: first)
            #expect(await cache.cachedByteCount == 4)
            await cache.removeCachedData()
            #expect(await cache.cachedByteCount == 0)
        }
        #expect(await counter.calls == 10)
    }

    @Test func failuresCanBeRetried() async throws {
        let cache = ArtworkDataCache(loader: { _ in throw ArtworkLoadError.invalidResponse })
        for _ in 0..<2 {
            do { _ = try await cache.data(for: first); Issue.record("Failure ignored") }
            catch { #expect(error is ArtworkLoadError) }
        }
        #expect(await cache.subscriberCount == 0)
        #expect(await cache.cachedByteCount == 0)
    }
}
