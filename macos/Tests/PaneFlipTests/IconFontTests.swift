import AppKit
import XCTest

final class IconFontTests: XCTestCase {
    private let font = NSFont.systemFont(ofSize: 13)

    func testANameThatFitsIsUnchanged() {
        XCTAssertEqual(IconFont.fitting("Window", in: 200, font: font), "Window")
    }

    func testALongNameIsCutWithAnEllipsisAndFits() {
        let name = String(repeating: "Window title ", count: 10)
        let cut = IconFont.fitting(name, in: 100, font: font)
        XCTAssertTrue(cut.hasSuffix("…"))
        XCTAssertLessThanOrEqual(IconFont.width(of: cut, font: font), 100)
        XCTAssertLessThan(cut.count, name.count)
    }

    func testAnIconCharacterCountsAsItsRealWidth() {
        let icon = IconFont.width(of: "\u{E000}", font: font)
        XCTAssertEqual(icon, (13 * CGFloat(IconFont.advance) / 1000).rounded(.up))
    }
}
