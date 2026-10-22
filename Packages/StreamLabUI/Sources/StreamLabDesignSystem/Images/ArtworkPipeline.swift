import Foundation
import ImageIO
import StreamLabCatalogData

/// CGImage is an immutable decoded image; no mutable UIKit object crosses actors.
struct DecodedArtwork: @unchecked Sendable { let image: CGImage }

actor ArtworkPipeline {
    static let shared = ArtworkPipeline()
    private let dataCache: ArtworkDataCache
    private var cacheEpoch = UUID()

    init(dataCache: ArtworkDataCache = ArtworkDataCache(loader: { try await ArtworkLoader.load($0) })) {
        self.dataCache = dataCache
    }
    private var images: [URL: DecodedArtwork] = [:]
    private var order: [URL] = []
    private var cost = 0
    private let limit = 24 * 1024 * 1024

    func image(for url: URL) async throws -> DecodedArtwork {
        try Task.checkCancellation()
        if let image = images[url] { touch(url); return image }
        let epoch = cacheEpoch
        let data = try await dataCache.data(for: url)
        try Task.checkCancellation()
        if let image = images[url] { touch(url); return image }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 720,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ArtworkLoadError.invalidResponse }
        let decoded = DecodedArtwork(image: image)
        let size = image.bytesPerRow * image.height
        if epoch == cacheEpoch, size <= limit {
            images[url] = decoded; cost += size; touch(url)
            while cost > limit, let oldest = order.first {
                order.removeFirst()
                if let removed = images.removeValue(forKey: oldest) {
                    cost -= removed.image.bytesPerRow * removed.image.height
                }
            }
        }
        return decoded
    }

    private func touch(_ url: URL) { order.removeAll { $0 == url }; order.append(url) }
}

// Views retain their currently displayed image. Only reusable cache ownership is released.
extension ArtworkPipeline {
    func releaseMemory() async {
        cacheEpoch = UUID()
        images.removeAll(); order.removeAll(); cost = 0
        await dataCache.removeCachedData()
    }
    var cachedDecodedBytes: Int { cost }
}
