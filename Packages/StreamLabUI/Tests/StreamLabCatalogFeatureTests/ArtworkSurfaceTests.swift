import Testing
import UIKit
@testable import StreamLabDesignSystem

@Suite("Artwork pixel bounds")
@MainActor struct ArtworkSurfaceTests {
    private func fixture() throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return try #require(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 20, y: 0, width: 20, height: 20))
        }.cgImage)
    }

    @Test func aspectFillClipsCornersAndDoesNotInterceptTouches() throws {
        let view = ArtworkImageView()
        view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        view.display(try fixture())
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image {
            view.layer.render(in: $0.cgContext)
        }
        let image = try #require(rendered.cgImage)
        var bytes = [UInt8](repeating: 0, count: 20 * 20 * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: 20, height: 20,
                bitsPerComponent: 8, bytesPerRow: 80, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: view.bounds)
        }
        #expect(bytes[(10 * 20 + 7) * 4] > 200)
        #expect(bytes[(10 * 20 + 13) * 4 + 2] > 200)
        // Core Animation antialiasing can leave a small edge coverage value.
        // An unclipped rectangular image would have alpha 255 here.
        #expect(bytes[3] < 32)
        #expect(bytes[(10 * 20 + 10) * 4 + 3] > 240)
        #expect(view.hitTest(CGPoint(x: 10, y: 10), with: nil) == nil)
        #expect(view.accessibilityElementsHidden)
    }
}
