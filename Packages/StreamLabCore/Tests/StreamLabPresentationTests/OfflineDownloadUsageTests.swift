import Foundation
import Testing
@testable import StreamLabDomain

@Suite("Download storage accounting") struct OfflineDownloadUsageTests {
    private func item(_ state: OfflineDownload.State, _ bytes: Int64, profile: String = "a") -> OfflineDownload {
        var record = OfflineDownload(accountID: "account", profileID: profile, titleID: UUID().uuidString, title: "Sample")
        record.state = state; record.bytes = bytes
        return record
    }
    @Test func emptyAndQueuedDoNotReserveSpace() throws {
        let empty = try OfflineDownloadBudget.usage(in: [])
        let queued = try OfflineDownloadBudget.usage(in: [item(.queued, 0)])
        #expect(empty == queued)
        #expect(empty.remainingBytes == 1_000_000_000)
        #expect(empty.fraction == 0)
    }
    @Test func activeAndRemovingDoNotDoubleCountFiles() throws {
        let usage = try OfflineDownloadBudget.usage(in: [item(.paused, 100_000_000), item(.removing, 200_000_000)])
        #expect(usage.otherFileBytes == 300_000_000)
        #expect(usage.reservedBytes == 700_000_000)
        #expect(usage.chargedBytes == 1_000_000_000)
        #expect(usage.remainingBytes == 0 && usage.fraction == 1)
    }
    @Test func completionReleasesReservationAcrossProfiles() throws {
        let records = [item(.complete, 100_000_000), item(.complete, 200_000_000, profile: "b"), item(.failed, 50_000_000)]
        let usage = try OfflineDownloadBudget.usage(in: records)
        #expect(usage.completedBytes == 300_000_000)
        #expect(usage.otherFileBytes == 50_000_000)
        #expect(usage.reservedBytes == 0 && usage.remainingBytes == 650_000_000)
        #expect(try OfflineDownloadBudget.evictions(in: records).isEmpty)
    }
    @Test func overBudgetIsClampedWithoutHidingActualUsage() throws {
        let usage = try OfflineDownloadBudget.usage(in: [item(.downloading, 1_100_000_000)])
        #expect(usage.chargedBytes == 1_100_000_000)
        #expect(usage.reservedBytes == 0)
        #expect(usage.remainingBytes == 0 && usage.fraction == 1)
    }
    @Test func invalidAndOverflowingMetadataCannotLookLikeFreeSpace() {
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.usage(in: [item(.failed, -1)])
        }
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.usage(in: [item(.complete, Int64.max), item(.downloading, 0)])
        }
    }
}
