import Foundation
import Testing
@testable import StreamLabDomain

@Suite("Download transfer failure messages") struct OfflineDownloadFailureTests {
    @Test func directDiskError() {
        #expect(OfflineDownloadFailure.message(for: CocoaError(.fileWriteOutOfSpace)) == OfflineDownloadFailure.insufficientSpace)
    }
    @Test func wrappedDiskError() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: 28)
        let wrapped = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotWriteToFile,
                              userInfo: [NSUnderlyingErrorKey: underlying])
        #expect(OfflineDownloadFailure.message(for: wrapped) == OfflineDownloadFailure.insufficientSpace)
    }
    @Test func cancellationIsNotAssumedToBeDiskExhaustion() {
        #expect(OfflineDownloadFailure.message(for: URLError(.cancelled)) == OfflineDownloadFailure.generic)
    }
    @Test func unrelatedErrorAndMissingError() {
        #expect(OfflineDownloadFailure.message(for: CocoaError(.fileReadNoPermission)) == OfflineDownloadFailure.generic)
        #expect(OfflineDownloadFailure.message(for: nil) == OfflineDownloadFailure.generic)
    }
}
