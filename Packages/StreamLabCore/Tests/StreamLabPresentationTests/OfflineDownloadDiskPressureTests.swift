import Foundation
import Testing
@testable import StreamLabDomain

@Suite("Download physical disk reclaim planning") struct OfflineDownloadDiskPressureTests {
    private func item(_ bytes: Int64, age: Double, pinned: Bool = false) -> OfflineDownload {
        var value = OfflineDownload(accountID: "a", profileID: "p", titleID: UUID().uuidString, title: "Sample", now: Date(timeIntervalSince1970: age))
        value.state = .complete; value.bytes = bytes; value.pinned = pinned
        return value
    }
    @Test func lowPhysicalCapacityRequiresEvictionEvenUnderBudget() throws {
        let oldest = item(100_000_000, age: 1), newer = item(100_000_000, age: 2)
        #expect(try OfflineDownloadBudget.evictions(in: [newer, oldest], minimumReclaim: 50_000_000) == [oldest.id])
    }
    @Test func physicalAndBudgetShortagesAreBothSatisfied() throws {
        let oldest = item(300_000_000, age: 1), newer = item(300_000_000, age: 2)
        #expect(try OfflineDownloadBudget.evictions(in: [newer, oldest], minimumReclaim: 400_000_000) == [oldest.id, newer.id])
    }
    @Test func pinsAndPlaybackLeasesCannotBeReclaimed() {
        let pin = item(300_000_000, age: 1, pinned: true), playing = item(300_000_000, age: 2)
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.evictions(in: [pin, playing], protected: [playing.id], minimumReclaim: 1)
        }
    }
    @Test func insufficientCandidatesFailBeforeReturningPartialPlan() {
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.evictions(in: [item(100, age: 1)], minimumReclaim: 101)
        }
        #expect(throws: OfflineDownloadBudget.Failure.self) {
            try OfflineDownloadBudget.evictions(in: [], minimumReclaim: -1)
        }
    }
}
