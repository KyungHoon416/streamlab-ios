import AVKit
import Foundation
import OSLog

/// The presented player keeps ownership of its layer while PiP is outside the app.
/// Never dismiss the SwiftUI cover to start PiP: restoration returns to that same player.
// AVKit imports this delegate as nonisolated in Xcode 27. The conformance,
// not only the class, must be isolated. All delegate installation happens on MainActor.
@MainActor final class PlaybackPictureInPicture: NSObject, @MainActor AVPictureInPictureControllerDelegate {
    private var controller: AVPictureInPictureController?
    private weak var layer: AVPlayerLayer?
    private(set) var isRunning = false
    private var restoring = false
    private var automaticStartEnabled = false
    private var startRequested: ContinuousClock.Instant?
    var onStop: (() -> Void)?
    var onFailure: ((String) -> Void)?

    var supported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
    var possible: Bool { controller?.isPictureInPicturePossible == true }
    var canStartAutomatically: Bool { automaticStartEnabled && possible }

    func setAutomaticStartEnabled(_ enabled: Bool) {
        var allowed = enabled
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-disable-automatic-pip") { allowed = false }
        #endif
        automaticStartEnabled = allowed
        controller?.canStartPictureInPictureAutomaticallyFromInline = allowed
    }

    var hasAttachedLayer: Bool { layer != nil }

    func attach(_ layer: AVPlayerLayer, enabled: Bool) {
        guard enabled else {
            if self.layer != nil { invalidate() }
            return
        }
        guard self.layer !== layer else { return }
        invalidate()
        self.layer = layer
        Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackPiP").notice("pip_layer_attached")
        guard supported else { return }
        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.delegate = self
        // AVKit decides whether the user/system permits automatic PiP.
        controller?.canStartPictureInPictureAutomaticallyFromInline = automaticStartEnabled
        self.controller = controller
    }

    func start() {
        guard let controller, controller.isPictureInPicturePossible, !isRunning else { return }
        restoring = false
        isRunning = true // Protect the transition before the scene becomes inactive.
        startRequested = .now
        controller.startPictureInPicture()
    }

    func checkStartTimeout() {
        guard let startRequested, startRequested.duration(to: .now) >= .seconds(10),
              controller?.isPictureInPictureActive != true else { return }
        invalidate()
        onFailure?("작은 화면 전환이 지연되어 취소했습니다. 다시 시도해 주세요.")
    }

    func restore() {
        guard isRunning else { return }
        restoring = true
        controller?.stopPictureInPicture()
    }

    func invalidate() {
        let old = controller
        old?.delegate = nil
        old?.stopPictureInPicture()
        controller = nil
        layer = nil
        isRunning = false
        restoring = false
        startRequested = nil
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard pictureInPictureController === controller else { return }
        isRunning = true
        if startRequested == nil { startRequested = .now }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard pictureInPictureController === controller else { return }
        startRequested = nil
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                   failedToStartPictureInPictureWithError error: any Error) {
        guard pictureInPictureController === controller else { return }
        isRunning = false
        restoring = false
        startRequested = nil
        onFailure?("작은 화면 재생을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                   restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        guard pictureInPictureController === controller else { completionHandler(false); return }
        // The full-screen cover and player have remained installed throughout PiP.
        restoring = true
        completionHandler(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard pictureInPictureController === controller else { return }
        isRunning = false
        startRequested = nil
        if !restoring { onStop?() } // PiP X must not leave invisible audio playing.
        restoring = false
    }
}
