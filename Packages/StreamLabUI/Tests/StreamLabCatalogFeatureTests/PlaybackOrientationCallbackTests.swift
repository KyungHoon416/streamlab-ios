import Foundation
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackOrientationCallbackTests: XCTestCase {
    @MainActor
    func testRotationRejectionCanArriveOffMainActor() async {
        let handler = PlaybackOrientationSession.geometryErrorHandler(restoring: false)
        let wasBackground = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                handler(NSError(domain: "UIWindowSceneErrorDomain", code: 101))
                continuation.resume(returning: !Thread.isMainThread)
            }
        }
        XCTAssertTrue(wasBackground)
    }

    @MainActor
    func testRestoreRejectionCanArriveOffMainActor() async {
        let handler = PlaybackOrientationSession.geometryErrorHandler(restoring: true)
        let wasBackground = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                handler(NSError(domain: "UIWindowSceneErrorDomain", code: 101))
                continuation.resume(returning: !Thread.isMainThread)
            }
        }
        XCTAssertTrue(wasBackground)
    }
}
