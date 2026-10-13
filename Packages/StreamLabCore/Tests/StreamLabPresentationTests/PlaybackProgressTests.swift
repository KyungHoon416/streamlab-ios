import Foundation
import Testing
import StreamLabPresentation

@MainActor struct PlaybackProgressTests {
    @Test func persistsAndSeparatesProfileTitleAndSource() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let a = PlaybackProgressStore(profileID: "adult-a", defaults: defaults)
        a.save(titleID: "title", sourceID: "mp4", position: 12, duration: 30)
        let reopened = PlaybackProgressStore(profileID: "adult-a", defaults: defaults)
        #expect(reopened.position(titleID: "title", sourceID: "mp4", duration: 30) == 12)
        #expect(reopened.position(titleID: "other", sourceID: "mp4", duration: 30) == nil)
        #expect(reopened.position(titleID: "title", sourceID: "hls", duration: 30) == nil)
        let kids = PlaybackProgressStore(profileID: "kids", defaults: defaults)
        #expect(kids.position(titleID: "title", sourceID: "mp4", duration: 30) == nil)
    }
    @Test func completionAndRestartClearProgress() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackProgressStore(profileID: "a", defaults: defaults)
        store.save(titleID: "t", sourceID: "s", position: 15, duration: 30)
        store.save(titleID: "t", sourceID: "s", position: 29, duration: 30)
        #expect(store.position(titleID: "t", sourceID: "s", duration: 30) == nil)
        store.save(titleID: "t", sourceID: "s", position: 15, duration: 30)
        store.save(titleID: "t", sourceID: "s", position: 0, duration: 30)
        #expect(store.position(titleID: "t", sourceID: "s", duration: 30) == nil)
    }
    @Test func invalidValuesAndChangedDurationDoNotResume() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackProgressStore(profileID: "a", defaults: defaults)
        store.save(titleID: "t", sourceID: "s", position: 12, duration: 30)
        store.save(titleID: "t", sourceID: "s", position: .nan, duration: 30)
        #expect(store.position(titleID: "t", sourceID: "s", duration: 30) == 12)
        #expect(store.position(titleID: "t", sourceID: "s", duration: 120) == nil)
        #expect(store.position(titleID: "t", sourceID: "s", duration: .infinity) == nil)
    }
}
