import Foundation
import Testing
import StreamLabDomain

@Suite("C1 offline download budget") struct OfflineDownloadBudgetTests {
    private func item(_ bytes: Int64, age: Double, pinned: Bool = false) -> OfflineDownload {
        var value = OfflineDownload(accountID: "a", profileID: "p", titleID: UUID().uuidString,
                                    title: "Demo", now: Date(timeIntervalSince1970: age))
        value.bytes = bytes; value.state = .complete; value.pinned = pinned
        return value
    }
    @Test func exactBudgetNeedsNoEviction() throws {
        #expect(try OfflineDownloadBudget.evictions(in: [item(500_000_000, age: 1)]).isEmpty)
    }
    @Test func evictsLeastRecentlyUsedAndHonorsPins() throws {
        let pin = item(400_000_000, age: 0, pinned: true)
        let old = item(200_000_000, age: 1), recent = item(100_000_000, age: 2)
        #expect(try OfflineDownloadBudget.evictions(in: [recent, pin, old]) == [old.id])
    }
    @Test func cannotEvictPlayingOrPinnedAssets() {
        let playing = item(600_000_000, age: 0)
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.evictions(in: [playing], protected: [playing.id])
        }
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.evictions(in: [item(600_000_000, age: 0, pinned: true)])
        }
    }
    @Test func reservesActiveDownloadsBeforeAdmittingMore() throws {
        var active = item(1, age: 1); active.state = .downloading
        #expect(try OfflineDownloadBudget.evictions(in: [active]).isEmpty)
        #expect(throws: OfflineDownloadBudget.Failure.self) { try OfflineDownloadBudget.evictions(in: [active, active]) }
        #expect(OfflineDownloadBudget.concurrentLimit == 2)
    }
    @Test func invalidAndOverflowingSizesFailClosed() {
        for size: Int64 in [-1, Int64.max] {
            #expect(throws: OfflineDownloadBudget.Failure.self) { try OfflineDownloadBudget.evictions(in: [item(size, age: 0), item(size, age: 1)]) }
        }
        #expect(throws: OfflineDownloadBudget.Failure.self) { try OfflineDownloadBudget.evictions(in: [], required: 0) }
    }
    @Test func storedPathsCannotEscapeContainer() {
        let root = URL(fileURLWithPath: "/tmp/streamlab-download-path-test")
        #expect(OfflineDownloadBudget.localURL(path: "Library/Caches/demo.movpkg", home: root) != nil)
        for path in ["", "/tmp/demo.movpkg", "../demo.movpkg", "Library/../../demo.movpkg", "Library/other.json"] {
            #expect(OfflineDownloadBudget.localURL(path: path, home: root) == nil)
        }
    }
    @Test func systemNoFollowAliasStaysWithinContainer() {
        let root = URL(fileURLWithPath: "/tmp/streamlab-download-path-test")
        let ordinary = root.appendingPathComponent("Library/demo.movpkg")
        let alias = URL(fileURLWithPath: "/.nofollow" + ordinary.path)
        #expect(OfflineDownloadBudget.relativePath(location: ordinary, home: root) == "Library/demo.movpkg")
        #expect(OfflineDownloadBudget.relativePath(location: alias, home: root) == "Library/demo.movpkg")
        #expect(OfflineDownloadBudget.relativePath(location: URL(fileURLWithPath: "/.nofollow/tmp/other/demo.movpkg"), home: root) == nil)
        #expect(OfflineDownloadBudget.relativePath(location: URL(string: "https://example.com/demo.movpkg")!, home: root) == nil)
    }
    @Test func recordsRoundTripScopesStatesAndPins() throws {
        var record = item(1234, age: 5, pinned: true)
        record.relativePath = "Library/Caches/demo.movpkg"
        let restored = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(record))
        #expect(restored == record)
        #expect(restored.accountID == "a" && restored.profileID == "p")
    }
}
