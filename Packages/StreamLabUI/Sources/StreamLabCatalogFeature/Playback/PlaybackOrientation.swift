import SwiftUI
import UIKit
import OSLog
import StreamLabPresentation

/// One rotation lifetime per player, independent of representable reconstruction.
@MainActor final class PlaybackOrientationSession: ObservableObject {
    private let logger = Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackOrientation")
    private weak var presenterScene: UIWindowScene?
    private weak var scene: UIWindowScene?
    private var originalOrientation: UIInterfaceOrientationMask?
    private var requestedLandscape: Bool?
    private var finished = false
    private var restored = false

    func attachPresenter(to scene: UIWindowScene) {
        presenterScene = scene
    }

    /// Capture before presenting: the player's first callback may already be landscape.
    func begin() {
        finished = false
        restored = false
        requestedLandscape = nil
        originalOrientation = nil
        scene = nil
        if let presenterScene {
            capture(presenterScene)
            logger.notice("begin: captured presenter orientation mask=\(self.originalOrientation?.rawValue ?? 0)")
        } else {
            logger.error("begin: presenter scene unavailable; capture deferred")
        }
    }

    private func capture(_ scene: UIWindowScene) {
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

    func request(in scene: UIWindowScene, landscape: Bool) {
        guard !finished else { return }
        if originalOrientation == nil {
            capture(scene)
            logger.notice("request: fallback capture mask=\(self.originalOrientation?.rawValue ?? 0)")
        }
        guard requestedLandscape != landscape else { return }
        requestedLandscape = landscape
        logger.notice("request: landscape=\(landscape)")
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscape : .portrait),
                                    errorHandler: Self.geometryErrorHandler(restoring: false))
    }

    /// Freeze outgoing callbacks before dismissal starts; retain the original geometry.
    func stopRequests() {
        finished = true
    }

    /// Called by the presenting view only after the full-screen cover has dismissed.
    func finish() {
        stopRequests()
        guard !restored else { return }
        restored = true
        guard let scene, let originalOrientation else {
            logger.error("finish: missing scene or original orientation")
            return
        }
        self.scene = nil
        logger.notice("finish: restoring mask=\(originalOrientation.rawValue)")
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: originalOrientation),
                                    errorHandler: Self.geometryErrorHandler(restoring: true))
    }

    // UIKit may invoke the error handler off the main queue. Creating this closure
    // inside the MainActor methods above gives it an invalid actor precondition.
    // Keep this logging-only callback nonisolated; never capture session/UI state.
    nonisolated static func geometryErrorHandler(restoring: Bool) -> @Sendable (any Error) -> Void {
        let logger = Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackOrientation")
        return { error in
            if restoring {
                logger.error("restore declined: \(SafeDiagnosticError.summary(error), privacy: .public)")
            } else {
                logger.error("rotation declined: \(SafeDiagnosticError.summary(error), privacy: .public)")
            }
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
        controller.session = session
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

/// Resolves the presenting window without consulting global connectedScenes.
@MainActor struct PlaybackPresenterScene: UIViewRepresentable {
    let session: PlaybackOrientationSession

    func makeUIView(context: Context) -> SceneView {
        let view = SceneView()
        view.session = session
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SceneView, context: Context) {
        view.session = session
        view.attachScene()
    }

    final class SceneView: UIView {
        weak var session: PlaybackOrientationSession?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachScene()
        }

        func attachScene() {
            guard let scene = window?.windowScene else { return }
            session?.attachPresenter(to: scene)
        }
    }
}
