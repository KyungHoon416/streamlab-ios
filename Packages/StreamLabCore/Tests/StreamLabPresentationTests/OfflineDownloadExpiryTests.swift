import Foundation
import Testing
@testable import StreamLabDomain

@Suite("Download Mock expiration") struct OfflineDownloadExpiryTests {
    private let deadline = Date(timeIntervalSince1970: 1_000)
    private func item() -> OfflineDownload {
        var value = OfflineDownload(accountID: "a", profileID: "p", titleID: "t", title: "Sample")
        value.state = .complete; value.bytes = 600_000_000; value.expiresAt = deadline
        return value
    }
    @Test func expiresAtBoundaryAndCannotBeUndoneByClockRollback() {
        var value = item()
        let before = value.expire(at: deadline.addingTimeInterval(-1))
        #expect(!before)
        let atBoundary = value.expire(at: deadline)
        #expect(atBoundary)
        #expect(value.state == .expired)
        #expect(value.isExpired(at: deadline.addingTimeInterval(-100)))
        let changed = value.expire(at: deadline.addingTimeInterval(100))
        #expect(!changed)
    }
    @Test func incompleteTransfersDoNotExpire() {
        for state in [OfflineDownload.State.queued, .downloading, .paused, .failed, .removing] {
            var value = item(); value.state = state
            let changed = value.expire(at: deadline.addingTimeInterval(100))
        #expect(!changed)
            #expect(value.state == state)
        }
    }
    @Test func expiredFilesStillCountAndPinsStillProtect() throws {
        var value = item(); value.expire(at: deadline)
        let usage = try OfflineDownloadBudget.usage(in: [value])
        #expect(usage.otherFileBytes == value.bytes)
        #expect(usage.remainingBytes == 400_000_000)
        #expect(try OfflineDownloadBudget.evictions(in: [value]) == [value.id])
        value.pinned = true
        #expect(throws: OfflineDownloadBudget.Failure.self) { try OfflineDownloadBudget.evictions(in: [value]) }
    }
    @Test func expiryAndExpiredStateRoundTrip() throws {
        var value = item(); value.expire(at: deadline)
        let restored = try JSONDecoder().decode(OfflineDownload.self, from: JSONEncoder().encode(value))
        #expect(restored == value)
        #expect(restored.isExpired(at: deadline))
    }
    @Test func legacyRecordDecodesWithoutExpiryForMigration() throws {
        let data = try JSONEncoder().encode(item())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "expiresAt")
        let value = try JSONDecoder().decode(OfflineDownload.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(value.expiresAt == nil)
        #expect(value.state == .complete)
        #expect(OfflineDownload.mockValidity == 604_800)
    }
}
