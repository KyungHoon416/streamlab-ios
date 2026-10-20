import Foundation
import Testing
@testable import StreamLabDomain

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
    @Test func deviceAliasComparisonDoesNotDependOnHostSymlinks() {
        let suffix = "/mobile/Containers/Data/Application/TEST/Library/demo.movpkg"
        #expect(OfflineDownloadBudget.containerComparisonPath("/private/var" + suffix) == "/var" + suffix)
        #expect(OfflineDownloadBudget.containerComparisonPath("/var" + suffix) == "/var" + suffix)
        #expect(OfflineDownloadBudget.containerComparisonPath("/private/variant/demo.movpkg") == "/private/variant/demo.movpkg")
        #expect(OfflineDownloadBudget.containerComparisonPath("/tmp/private/var/demo.movpkg") == "/tmp/private/var/demo.movpkg")
    }
    @Test func physicalDeviceCallbackAcceptsOnlySameContainer() {
        let prefix = "/var/mobile/Containers/Data/Application/"
        let root = URL(fileURLWithPath: prefix + "TEST-CONTAINER")
        let relative = "Library/com.apple.UserManagedAssets.Test/demo.movpkg"
        let callback = URL(fileURLWithPath: "/.nofollow/private" + root.path + "/" + relative)
        #expect(OfflineDownloadBudget.relativePath(location: callback, home: root) == relative)
        #expect(OfflineDownloadBudget.localURL(path: relative, home: root) != nil)
        for other in ["OTHER-CONTAINER", "TEST-CONTAINER-extra"] {
            let outside = URL(fileURLWithPath: "/.nofollow/private" + prefix + other + "/" + relative)
            #expect(OfflineDownloadBudget.relativePath(location: outside, home: root) == nil)
        }
    }
    @Test func symlinkCannotEscapeHomeAfterAliasNormalization() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let home = base.appendingPathComponent("home"), outside = base.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent("escape"), withDestinationURL: outside)
        #expect(OfflineDownloadBudget.localURL(path: "escape/demo.movpkg", home: home) == nil)
        #expect(OfflineDownloadBudget.relativePath(location: home.appendingPathComponent("escape/demo.movpkg"), home: home) == nil)
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent("dangling"), withDestinationURL: base.appendingPathComponent("not-created"))
        #expect(OfflineDownloadBudget.localURL(path: "dangling/demo.movpkg", home: home) == nil)
        try FileManager.default.createSymbolicLink(atPath: home.appendingPathComponent("loop").path, withDestinationPath: "loop")
        #expect(OfflineDownloadBudget.localURL(path: "loop/demo.movpkg", home: home) == nil)
        try FileManager.default.createSymbolicLink(atPath: home.appendingPathComponent("relative").path, withDestinationPath: "../outside")
        #expect(OfflineDownloadBudget.localURL(path: "relative/demo.movpkg", home: home) == nil)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("inside"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: home.appendingPathComponent("safe").path, withDestinationPath: "inside")
        #expect(OfflineDownloadBudget.localURL(path: "safe/demo.movpkg", home: home) != nil)
    }
    @Test func recordsRoundTripScopesStatesAndPins() throws {
        var record = item(1234, age: 5, pinned: true)
        record.relativePath = "Library/Caches/demo.movpkg"
        let restored = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(record))
        #expect(restored == record)
        #expect(restored.accountID == "a" && restored.profileID == "p")
    }
}
