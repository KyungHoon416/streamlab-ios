import Foundation
import Testing
import StreamLabCatalogData
@testable import StreamLabDesignSystem

private actor ImageLoadGate {
    private var continuation: CheckedContinuation<Data, Never>?
    func load() async -> Data {
        await withCheckedContinuation { continuation = $0 }
    }
    var waiting: Bool { continuation != nil }
    func finish(_ data: Data) { continuation?.resume(returning: data); continuation = nil }
}

@Suite("Decoded artwork memory pressure")
struct ArtworkMemoryTests {
    @Test func clearsBothCachesAndReloadsTenTimes() async throws {
        let url = try #require(StreamLabTheme.bundledArtworkURL(seed: 0))
        let cache = ArtworkDataCache(loader: { try Data(contentsOf: $0) })
        let pipeline = ArtworkPipeline(dataCache: cache)
        for _ in 0..<10 {
            let image = try await pipeline.image(for: url)
            #expect(image.image.width > 0)
            #expect(await pipeline.cachedDecodedBytes > 0)
            #expect(await cache.cachedByteCount > 0)
            await pipeline.releaseMemory()
            #expect(await pipeline.cachedDecodedBytes == 0)
            #expect(await cache.cachedByteCount == 0)
            // The image retained by the requesting view remains usable after cache purge.
            #expect(image.image.height > 0)
        }
    }

    @Test func lateDecodeDoesNotRefillPurgedCache() async throws {
        let url = try #require(StreamLabTheme.bundledArtworkURL(seed: 1))
        let fixture = try Data(contentsOf: url)
        let gate = ImageLoadGate()
        let cache = ArtworkDataCache(loader: { _ in await gate.load() })
        let pipeline = ArtworkPipeline(dataCache: cache)
        let request = Task { try await pipeline.image(for: url) }
        for _ in 0..<10000 {
            if await gate.waiting { break }
            await Task.yield()
        }
        #expect(await gate.waiting)
        await pipeline.releaseMemory()
        await gate.finish(fixture)
        let result = try await request.value
        #expect(result.image.width > 0)
        #expect(await pipeline.cachedDecodedBytes == 0)
        #expect(await cache.cachedByteCount == 0)
        #expect(await cache.subscriberCount == 0)
    }
}
