import Foundation
import Testing
import StreamLabDomain
@testable import StreamLabCatalogData

@Suite("Published Firestore catalog")
struct FirestoreCatalogRepositoryTests {
    private func response(rating: String = "ALL", stream: String = "https://example.com/master.m3u8", published: Bool = true) throws -> Data {
        var fields: [String: Any] = [:]
        for (key, value) in ["id":"sample", "name":"Sample", "synopsis":"Example", "genre":"Test", "kind":"movie", "rating":rating, "artworkURL":"", "streamURL":stream] {
            fields[key] = ["stringValue":value]
        }
        for (key, value) in ["year":"2026", "durationMinutes":"30", "visualSeed":"1", "popularity":"10"] { fields[key] = ["integerValue":value] }
        fields["published"] = ["booleanValue":published]
        return try JSONSerialization.data(withJSONObject: [["document":["fields":fields]]])
    }
    @Test func queryIsPublishedOnlyAndPreservesStream() async throws {
        let data = try response()
        let repo = FirestoreCatalogRepository(projectID: "example-project") { request in
            #expect(request.httpMethod == "POST")
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let query = try #require(json["structuredQuery"] as? [String: Any])
            #expect(query["limit"] as? Int == 201)
            #expect(String(decoding: body, as: UTF8.self).contains("published"))
            return data
        }
        let home = try await repo.home(profile: ViewerProfile.demo[0])
        #expect(home.hero.streamURL?.absoluteString == "https://example.com/master.m3u8")
        #expect(home.continueWatching.isEmpty)
    }
    @Test func restrictedTitleCannotBeOpenedByKids() async throws {
        let data = try response(rating: "19+")
        let repo = FirestoreCatalogRepository(projectID: "example-project") { _ in data }
        #expect(try await repo.detail(id: "sample", profile: ViewerProfile.demo[2]) == nil)
    }
    @Test func malformedOrPrivateResponseFailsClosed() async throws {
        for data in [try response(published: false), try response(stream: "http://example.com/a.m3u8"), try response(stream: "")] {
            let repo = FirestoreCatalogRepository(projectID: "example-project") { _ in data }
            await #expect(throws: (any Error).self) { try await repo.home(profile: ViewerProfile.demo[0]) }
        }
    }
    @Test func networkFailureHasNoDemoFallback() async throws {
        let repo = FirestoreCatalogRepository(projectID: "example-project") { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) { try await repo.home(profile: ViewerProfile.demo[0]) }
    }
    @Test func emptyPublishedCatalogIsExplicitError() async throws {
        let repo = FirestoreCatalogRepository(projectID: "example-project") { _ in Data("[{}]".utf8) }
        await #expect(throws: CatalogFailure.emptyCatalog) { try await repo.home(profile: ViewerProfile.demo[0]) }
    }
}
