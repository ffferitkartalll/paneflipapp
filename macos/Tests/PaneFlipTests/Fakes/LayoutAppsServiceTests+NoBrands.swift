import AppKit
import XCTest
import CoreGraphics
import PaneFlipCore

extension LayoutAppsServiceTests {
    final class NoBrands: BrandGlyphSource {
        var version = 0
        func glyph(forApp name: String) -> NSImage? { nil }
    }
}
