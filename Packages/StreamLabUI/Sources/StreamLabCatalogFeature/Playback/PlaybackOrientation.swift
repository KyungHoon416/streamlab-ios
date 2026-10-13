import SwiftUI
import UIKit

/// One rotation lifetime per player, independent of representable reconstruction.
@MainActor final class PlaybackOrientationSession: ObservableObject {
    private weak var scene: UIWindowScene?
    private var originalOrientation: UIInterfaceOrientationMask?
    private var requestedLandscape: Bool?
    private var finished = false

    func request(in scene: UIWindowScene, landscape: Bool) {
        guard !finished else { return }
        if originalOrientation == nil {
            self.scene = scene
            let orientation: UIInterfaceOrientation
            if #available(iOS 26.0, *) {
                orientation = scene.effectiveGeometry.interfaceOrientation
            } else {
                orientation = scene.interfaceOrientation
            }
            switch orientation {
            case .landscapeLeft: originalOrientation = .landscapeLeft
            case .landscapeRight: originalOrientation = .landscapeRight
            case .portraitUpsideDown: originalOrientation = .portraitUpsideDown
            default: originalOrientation = .portrait
            }
        }
        guard requestedLandscape != landscape else { return }
        requestedLandscape = landscape
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscape : .portrait)) { error in
            print("[PlaybackOrientation] Rotation request declined: \(error.localizedDescription)")
        }
    }

    func finish() {
        guard !finished else { return }
        // Close before requesting restoration: late controller callbacks must not rotate again.
        finished = true
        guard let scene, let originalOrientation else { return }
        self.scene = nil
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: originalOrientation)) { error in
            print("[PlaybackOrientation] Restore request declined: \(error.localizedDescription)")
        }
    }
}

@MainActor struct PlaybackOrientation: UIViewControllerRepresentable {
    let landscape: Bool
    let session: PlaybackOrientationSession

    func makeUIViewController(context: Context) -> OrientationController {
        let controller = OrientationController()
        controller.session = session
        controller.landscape = landscape
        return controller
    }

    func updateUIViewController(_ controller: OrientationController, context: Context) {
        controller.landscape = landscape
        controller.requestOrientation()
    }

    static func dismantleUIViewController(_ controller: OrientationController, coordinator: Void) {
        // Removing a bridge is not necessarily closing the player.
        controller.session = nil
    }

    final class OrientationController: UIViewController {
        var landscape = true
        var session: PlaybackOrientationSession?

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            requestOrientation()
        }

        func requestOrientation() {
            guard let scene = view.window?.windowScene else { return }
            session?.request(in: scene, landscape: landscape)
        }
    }
}
