import AVFoundation
import SwiftUI
import UIKit

/// Render only. PlaybackModel remains the sole owner of playback and its lifetime.
@MainActor struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer?
    let fillsScreen: Bool
    let allowsPictureInPicture: Bool
    let pictureInPicture: PlaybackPictureInPicture
    let onLayerAvailable: @MainActor (AVPlayerLayer) -> Void

    func makeCoordinator() -> PlaybackPictureInPicture { pictureInPicture }

    func makeUIView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: SurfaceView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = fillsScreen ? .resizeAspectFill : .resizeAspect
        onLayerAvailable(view.playerLayer)
        pictureInPicture.attach(view.playerLayer, enabled: allowsPictureInPicture && player != nil)
    }

    static func dismantleUIView(_ view: SurfaceView, coordinator: PlaybackPictureInPicture) {
        coordinator.invalidate()
        view.playerLayer.player = nil
    }

    final class SurfaceView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
