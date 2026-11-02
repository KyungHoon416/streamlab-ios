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
        let unsupported = try title("https://example.com/file.html")
        #expect(OfflineDownload(downloadable: unsupported, accountID: "a", profile: ViewerProfile.demo[0]) == nil)
        let sample = OfflineDownload(accountID: "a", profileID: "b", titleID: "c", title: "Sample")
        let legacy = try JSONEncoder().encode(sample)
        let restoredSample = try JSONDecoder().decode(OfflineDownload.self, from: legacy)
        #expect(restoredSample.catalogTitle == nil)
        #expect(restoredSample.transferURL(sampleURL: sampleURL) == sampleURL)
    }
    @Test func mp4InstallationRejectsErrorPagesAndPreservesDownloadedBytes() throws {
        let media = try title("https://example.com/video.mp4")
        let item = try #require(OfflineDownload(downloadable: media, accountID: "a", profile: ViewerProfile.demo[0]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let temp = root.appendingPathComponent("download.tmp")
        let destination = try #require(item.mp4Location(home: root))
        try Data("<html>an error</html>".utf8).write(to: temp)
        #expect(throws: URLError.self) { try item.installMP4(from: temp, home: root) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        let bytes = Data([0,0,0,16] + Array("ftypisom0000".utf8))
        try bytes.write(to: temp)
        try item.installMP4(from: temp, home: root)
        #expect(try Data(contentsOf: destination) == bytes)
        #expect(!FileManager.default.fileExists(atPath: temp.path))
    }

}
