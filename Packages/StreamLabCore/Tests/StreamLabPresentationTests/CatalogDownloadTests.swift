import Foundation
import Testing
import StreamLabDomain

struct CatalogDownloadTests {
    private func title(_ stream: String, rating: String = "ALL") throws -> CatalogTitle {
        let object: [String: Any] = ["id":"movie", "name":"Example", "synopsis":"", "genre":"test",
            "year":2026, "durationMinutes":5, "kind":"movie", "rating":rating, "streamURL":stream,
            "visualSeed":1, "popularity":0]
        return try JSONDecoder().decode(CatalogTitle.self, from: JSONSerialization.data(withJSONObject: object))
    }

    @Test func storedHLSRetainsActualMediaAndRejectsUnsupportedOrRestrictedTitles() throws {
        let url = "https://example.com/playlist.m3u8?version=2"
        let hls = try title(url, rating: "19+")
        let item = try #require(OfflineDownload(downloadable: hls, accountID: "a", profile: ViewerProfile.demo[0]))
        let restored = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(item))
        #expect(restored.catalogTitle == hls)
        let sampleURL = try #require(URL(string: "https://example.com/sample.m3u8"))
        #expect(restored.transferURL(sampleURL: sampleURL)?.absoluteString == url)
        #expect(OfflineDownload(downloadable: hls, accountID: "a", profile: ViewerProfile.demo[2]) == nil)
        let mp4 = try title("https://example.com/file.mp4")
        #expect(OfflineDownload(downloadable: mp4, accountID: "a", profile: ViewerProfile.demo[0]) == nil)
        let sample = OfflineDownload(accountID: "a", profileID: "b", titleID: "c", title: "Sample")
        let legacy = try JSONEncoder().encode(sample)
        let restoredSample = try JSONDecoder().decode(OfflineDownload.self, from: legacy)
        #expect(restoredSample.catalogTitle == nil)
        #expect(restoredSample.transferURL(sampleURL: sampleURL) == sampleURL)
    }
}
