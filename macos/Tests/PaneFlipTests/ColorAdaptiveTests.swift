import AppKit
import SwiftUI
import XCTest

/// A colour that follows the appearance: it is the one of the appearance it is drawn in, whenever that is, and the dynamic window colours inside it are not fixed.
final class ColorAdaptiveTests: XCTestCase {
    private func resolved(_ color: NSColor, dark: Bool) -> NSColor? {
        var found: NSColor?
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance { found = color.usingColorSpace(.sRGB) }
        return found
    }

    func testAColourIsTheLightOrTheDarkOneByTheAppearanceItIsDrawnIn() {
        let color = NSColor(light: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), dark: NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        XCTAssertEqual(resolved(color, dark: false)?.redComponent, 1)
        XCTAssertEqual(resolved(color, dark: true)?.blueComponent, 1)
        XCTAssertEqual(resolved(color, dark: false)?.blueComponent, 0)
    }

    func testTheCanvasIsBlackInTheDarkAppearanceAndTheWindowsOwnInTheLightOne() {
        let canvas = NSColor(Color.canvas)
        XCTAssertEqual(resolved(canvas, dark: true)?.brightnessComponent, 0)
        XCTAssertEqual(resolved(canvas, dark: false)?.brightnessComponent ?? 0, resolved(.windowBackgroundColor, dark: false)?.brightnessComponent ?? 1, accuracy: 0.01)
    }

    func testTheContrastColourIsWhiteOnDarkAndBlackOnLight() {
        XCTAssertEqual(resolved(.contrast, dark: true)?.brightnessComponent, 1)
        XCTAssertEqual(resolved(.contrast, dark: false)?.brightnessComponent, 0)
    }

    func testTheOwnGreenReadsOnALightGroundAndTheDarkInkReadsOnTheMint() {
        // Against white, the app's deep green (the one of the light appearance) must pass 4.5 to 1, as text needs.
        func luminance(_ c: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> CGFloat {
            func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue)
        }
        let deep = AppAccent.deep.rgb(dark: false)
        XCTAssertGreaterThan(1.05 / (luminance(deep) + 0.05), 4.5)
    }
}
