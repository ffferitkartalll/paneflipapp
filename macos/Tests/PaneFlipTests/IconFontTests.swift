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

    /// The OS/2 table of version 4 is 96 bytes; every field after the panose block moves if one byte is added.
    func testTheOS2TableHasItsFieldsWhereTheFormatPutsThem() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let font = IconFont.font(named: "Test", pngs: [png])
        func u16(_ offset: Int) -> Int { Int(font[offset]) << 8 | Int(font[offset + 1]) }
        func u32(_ offset: Int) -> Int { u16(offset) << 16 | u16(offset + 2) }
        let tables = u16(4)
        let record = try XCTUnwrap((0..<tables).map { 12 + $0 * 16 }.first { String(decoding: font[$0..<$0 + 4], as: UTF8.self) == "OS/2" })
        let start = u32(record + 8)
        XCTAssertEqual(u32(record + 12), 96)
        XCTAssertEqual(u16(start + 68), 800)   // sTypoAscender
        XCTAssertEqual(u16(start + 74), 800)   // usWinAscent
        XCTAssertEqual(u16(start + 76), 200)   // usWinDescent
    }
}
