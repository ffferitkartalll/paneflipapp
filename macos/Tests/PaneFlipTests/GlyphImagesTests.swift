import AppKit
import XCTest

final class GlyphImagesTests: XCTestCase {
    func testAPictureOfAnAppHasTheSizeAskedFor() {
        let font = GlyphImages(brands: CDNBrandGlyphs(isEnabled: { false }))
        let picture = font.image(bundleID: "com.example.app", appName: "App", icon: NSImage(size: NSSize(width: 8, height: 8)), size: 16)
        XCTAssertEqual(picture.size, NSSize(width: 16, height: 16))
    }
}
