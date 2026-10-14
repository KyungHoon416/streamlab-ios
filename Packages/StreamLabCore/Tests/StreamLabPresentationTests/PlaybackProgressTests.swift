import Foundation
import Testing
import StreamLabPresentation

@MainActor struct PlaybackProgressTests {
    @Test func adultProfilesKeepIndependentPositionsAfterReopening() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let a = PlaybackProgressStore(profileID: "adult-a", defaults: defaults)
        let b = PlaybackProgressStore(profileID: "adult-b", defaults: defaults)
        a.save(titleID: "same", sourceID: "hls", position: 30, duration: 98)
        #expect(b.position(titleID: "same", sourceID: "hls", duration: 98) == nil)
        b.save(titleID: "same", sourceID: "hls", position: 10, duration: 98)
        #expect(PlaybackProgressStore(profileID: "adult-a", defaults: defaults)
            .position(titleID: "same", sourceID: "hls", duration: 98) == 30)
        #expect(PlaybackProgressStore(profileID: "adult-b", defaults: defaults)
            .position(titleID: "same", sourceID: "hls", duration: 98) == 10)
    }

    @Test func rejectsRecordCopiedUnderAnotherProfileKey() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let a = PlaybackProgressStore(profileID: "adult-a", defaults: defaults)
        let b = PlaybackProgressStore(profileID: "adult-b", defaults: defaults)
        a.save(titleID: "same", sourceID: "hls", position: 30, duration: 98)
        func key(_ profile: String) -> String {
            "streamlab.progress.v1." + [profile, "same", "hls"]
                .map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
        }
        guard let savedRecord = defaults.data(forKey: key("adult-a")) else {
            Issue.record("Profile A must have a saved record before testing cross-profile rejection")
            return
        }
        defaults.set(savedRecord, forKey: key("adult-b"))
        #expect(b.position(titleID: "same", sourceID: "hls", duration: 98) == nil)
        #expect(b.recent().isEmpty)
        #expect(a.position(titleID: "same", sourceID: "hls", duration: 98) == 30)
    }

    @Test func recentDeduplicatesAndExcludesFinishedAndOtherProfiles() throws {
        let name = "progress-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PlaybackProgressStore(profileID: "a", defaults: defaults)
        store.save(titleID: "one", sourceID: "mp4", position: 10, duration: 30)
        store.save(titleID: "one", sourceID: "hls", position: 15, duration: 60)
        store.save(titleID: "done", sourceID: "mp4", position: 30, duration: 30)
        let other = PlaybackProgressStore(profileID: "kids", defaults: defaults)
        other.save(titleID: "private", sourceID: "mp4", position: 5, duration: 30)
        let entries = store.recent()
        #expect(entries.count == 1)
        #expect(entries.first?.titleID == "one")
        #expect(entries.first?.sourceID == "hls")
        #expect(entries.first?.position == 15)
        #expect(store.recent(limit: 0).isEmpty)
        #expect(other.recent().first?.titleID == "private")
    }

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
