import SwiftUI
import UIKit

/// Requests geometry only for the scene containing this player. No device KVC or global lock.
@MainActor struct PlaybackOrientation: UIViewControllerRepresentable {
    let landscape: Bool

    func makeUIViewController(context: Context) -> OrientationController {
        let controller = OrientationController()
        controller.landscape = landscape
        return controller
    }

    func updateUIViewController(_ controller: OrientationController, context: Context) {
        guard controller.landscape != landscape else { return }
        controller.landscape = landscape
        controller.requestOrientation()
    }

    static func dismantleUIViewController(_ controller: OrientationController, coordinator: Void) {
        controller.restoreOrientation()
    }

    final class OrientationController: UIViewController {
        var landscape = true
        private weak var playerScene: UIWindowScene?
        private var originalOrientation: UIInterfaceOrientationMask?

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
            if originalOrientation == nil {
                playerScene = scene
                // effectiveGeometry replaces the deprecated scene.interfaceOrientation on iOS 26.
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
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscape : .portrait)) { error in
                // Split View, Stage Manager or system policy may reject rotation. UI remains adaptive.
                print("[PlaybackOrientation] Rotation request declined: \(error.localizedDescription)")
            }
        }

        func restoreOrientation() {
            guard let scene = playerScene, let originalOrientation else { return }
            self.originalOrientation = nil
            playerScene = nil
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: originalOrientation)) { error in
                print("[PlaybackOrientation] Restore request declined: \(error.localizedDescription)")
            }
        }
    }
}
