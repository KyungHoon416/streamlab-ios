import Foundation
import Testing
import StreamLabDomain
import StreamLabPresentation

@MainActor struct CatalogVideoProgressTests {
    @Test func replacedVideoDoesNotRestorePreviousPlaybackPosition() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlaybackProgressStore(profileID: "viewer", defaults: defaults)
        let base = "https://firebasestorage.googleapis.com/v0/b/demo/o/"
        func key(_ path: String) throws -> String {
            CatalogVideoIdentity.progressID(for: try #require(URL(string: base + path)))
        }
        let original = try key("A.mp4?alt=media&token=first")
        store.save(titleID: "film", sourceID: original, position: 12, duration: 60)
        let renewed = try key("A.mp4?alt=media&token=renewed")
        let replacement = try key("B.mp4?alt=media&token=first")
        #expect(store.position(titleID: "film", sourceID: renewed, duration: 60) == 12)
        #expect(store.position(titleID: "film", sourceID: replacement, duration: 60) == nil)
    }
}
