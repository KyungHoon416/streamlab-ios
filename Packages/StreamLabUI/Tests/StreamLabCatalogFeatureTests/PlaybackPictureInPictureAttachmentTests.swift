import AVFoundation
import XCTest
@testable import StreamLabCatalogFeature

final class PlaybackPictureInPictureAttachmentTests: XCTestCase {
    @MainActor func testPreviewNeverAttachesAndSwitchingToPreviewDetaches() {
        let pip = PlaybackPictureInPicture()
        let layer = AVPlayerLayer()
        pip.attach(layer, enabled: false)
        XCTAssertFalse(pip.hasAttachedLayer)
        pip.attach(layer, enabled: true)
        XCTAssertTrue(pip.hasAttachedLayer)
        pip.attach(layer, enabled: false)
        XCTAssertFalse(pip.hasAttachedLayer)
        XCTAssertFalse(pip.isRunning)
        pip.attach(layer, enabled: true)
        XCTAssertTrue(pip.hasAttachedLayer)
        pip.invalidate()
        XCTAssertFalse(pip.hasAttachedLayer)
    }
}
