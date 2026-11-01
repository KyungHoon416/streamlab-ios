import AVFoundation
import Foundation
import XCTest
@testable import StreamLabCatalogFeature

private final class CallbackProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    func record(_ key: String) { lock.withLock { counts[key, default: 0] += 1 } }
    func count(_ key: String) -> Int { lock.withLock { counts[key, default: 0] } }
}

private final class CallbackWeakReference {
    weak var value: CallbackProbe?
    init(_ value: CallbackProbe?) { self.value = value }
}

final class PlaybackObserverLifecycleTests: XCTestCase {
    @MainActor func testAudioObserversUnregisterAndReleaseCapturedHandlerAcrossTenCycles() {
        let center = NotificationCenter.default
        for _ in 0..<10 {
            var probe: CallbackProbe? = CallbackProbe()
            let releasedProbe = CallbackWeakReference(probe)
            var observer: PlaybackAudioEventObserver? = PlaybackAudioEventObserver { [probe = probe!] event in
                switch event {
                case .interruptionBegan: probe.record("began")
                case .interruptionEnded: probe.record("ended")
                case .outputDisconnected: probe.record("route")
                case .volumeChanged: break // Initial KVO delivery is not a route/interruption.
                }
            }
            XCTAssertNotNil(observer)
            func post() {
                center.post(name: AVAudioSession.interruptionNotification, object: nil,
                            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
                center.post(name: AVAudioSession.interruptionNotification, object: nil,
                            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                                       AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
                center.post(name: AVAudioSession.routeChangeNotification, object: nil,
                            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
            }
            post()
            for key in ["began", "ended", "route"] { XCTAssertEqual(probe?.count(key), 1) }
            observer = nil
            post()
            for key in ["began", "ended", "route"] { XCTAssertEqual(probe?.count(key), 1, "Removed observer received \(key)") }
            probe = nil
            XCTAssertNil(releasedProbe.value, "Notification/KVO registration must not retain the callback capture")
        }
    }

    @MainActor func testItemAndResetObserversFilterAndUnregisterAcrossTenCycles() {
        let center = NotificationCenter.default
        let item = AVPlayerItem(url: URL(fileURLWithPath: "/unused-observer-fixture.mov"))
        let otherItem = AVPlayerItem(url: URL(fileURLWithPath: "/other-observer-fixture.mov"))
        for _ in 0..<10 {
            var probe: CallbackProbe? = CallbackProbe()
            let releasedProbe = CallbackWeakReference(probe)
            var end: PlaybackItemEndObserver? = PlaybackItemEndObserver(item: item,
                failure: { [probe = probe!] in probe.record("failure") },
                handler: { [probe = probe!] in probe.record("end") })
            var reset: PlaybackMediaResetObserver? = PlaybackMediaResetObserver { [probe = probe!] in probe.record("reset") }
            XCTAssertNotNil(end); XCTAssertNotNil(reset)
            for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
                center.post(name: name, object: otherItem)
            }
            XCTAssertEqual(probe?.count("end"), 0)
            XCTAssertEqual(probe?.count("failure"), 0)
            func post() {
                center.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: item)
                center.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
                center.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
            }
            post()
            for key in ["end", "failure", "reset"] { XCTAssertEqual(probe?.count(key), 1) }
            end = nil; reset = nil
            post()
            for key in ["end", "failure", "reset"] { XCTAssertEqual(probe?.count(key), 1) }
            probe = nil
            XCTAssertNil(releasedProbe.value)
        }
    }
}
