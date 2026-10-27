import SwiftUI
import UIKit

/// Decoded pixels stay on one layer. Bounds crop aspect-fill content without an
/// extra image view, geometry preference, rasterization cache or SwiftUI mask.
@MainActor struct ArtworkImageSurface: UIViewRepresentable {
    let image: CGImage

    func makeUIView(context: Context) -> ArtworkImageView { ArtworkImageView() }
    func updateUIView(_ view: ArtworkImageView, context: Context) { view.display(image) }
}

@MainActor final class ArtworkImageView: UIView {
    private var displayedImage: CGImage?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        layer.contentsGravity = .resizeAspectFill
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func display(_ image: CGImage) {
        guard displayedImage !== image else { return }
        displayedImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
    }
}
