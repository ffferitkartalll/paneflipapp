import XCTest
import CoreGraphics

final class WindowCornersTests: XCTestCase {
    /// A solid red window picture with rounded corners of `radius` pixels cut away to transparent.
    private func roundedPicture(size: Int = 200, radius: Int) -> CGImage {
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: CGFloat(radius),
                               cornerHeight: CGFloat(radius), transform: nil))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fillPath()
        return context.makeImage()!
    }

    private func alpha(_ image: CGImage, _ x: Int, _ y: Int) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel[3]
    }

    func testTheCornerRadiusIsMeasuredFromTheTransparentCorner() {
        for radius in [16, 26, 40] {
            XCTAssertEqual(Double(WindowCorners.squared(roundedPicture(radius: radius)).radius), Double(radius), accuracy: 3)
        }
    }

    func testASquarePictureHasNoRadius() {
        XCTAssertEqual(WindowCorners.squared(roundedPicture(radius: 0)).radius, 0)
    }

    func testFillingMakesEveryCornerPixelOpaqueAgain() {
        let picture = roundedPicture(radius: 30)
        XCTAssertEqual(alpha(picture, 0, 0), 0)
        let filled = WindowCorners.squared(picture).image
        for (x, y) in [(0, 0), (199, 0), (0, 199), (199, 199), (3, 5), (196, 194)] {
            XCTAssertEqual(alpha(filled, x, y), 255, "corner pixel \(x),\(y)")
        }
    }
}
