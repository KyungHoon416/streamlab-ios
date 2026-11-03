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
    @Test func onlyAChangedVideoOffersReplacement() throws {
        let base = "https://firebasestorage.googleapis.com/v0/b/example/o/"
        let first = try title(base + "first.mp4?alt=media&token=old")
        let saved = try #require(OfflineDownload(downloadable: first, accountID: "a", profile: ViewerProfile.demo[0]))
        let rotated = try title(base + "first.mp4?alt=media&token=new")
        let other = try title(base + "second.m3u8")
        #expect(!saved.hasNewVideo(rotated))
        #expect(saved.hasNewVideo(other))
        let sample = OfflineDownload(accountID: "a", profileID: "b", titleID: first.id, title: "Sample")
        #expect(!sample.hasNewVideo(other))
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

    @Test func watchedStateBelongsToOneCompletedDownloadAndSurvivesReopening() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let original = OfflineDownload(accountID: "a", profileID: "viewer", titleID: "movie", title: "Movie")
        var item = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(original))
        #expect(item.watchedAt == nil)
        let beforeDownload = item.markWatched(at: now)
        #expect(!beforeDownload)
        item.state = .complete
        item.expiresAt = now.addingTimeInterval(100)
        let afterExpiry = item.markWatched(at: now.addingTimeInterval(101))
        #expect(!afterExpiry)
        let firstEnd = item.markWatched(at: now)
        #expect(firstEnd)
        let secondEnd = item.markWatched(at: now.addingTimeInterval(1))
        #expect(!secondEnd)
        var restored = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(item))
        #expect(restored.watchedAt == now)
        restored.clearWatched()
        let cleared = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(restored))
        #expect(cleared.watchedAt == nil)
        #expect(cleared.id == item.id)
        #expect(cleared.state == .complete)
        let finishedAgain = restored.markWatched(at: now.addingTimeInterval(2))
        #expect(finishedAgain)
        #expect(original.watchedAt == nil)
    }

}
