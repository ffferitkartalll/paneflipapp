import AppKit
import XCTest

final class AppGlyphsTests: XCTestCase {
    func testEveryEntryOfTheTableResolves() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/PaneFlip/Resources/AppGlyphs.json").standardized
        let table = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: file))
        XCTAssertFalse(table.isEmpty)
        for (bundleID, glyph) in table {
            if glyph.hasPrefix("system:") {
                let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/\(glyph.dropFirst(7)).icns"
                XCTAssertTrue(FileManager.default.fileExists(atPath: path), "\(bundleID): \(glyph)")
            } else {
                XCTAssertNotNil(NSImage(systemSymbolName: glyph, accessibilityDescription: nil), "\(bundleID): \(glyph)")
            }
        }
    }
}
