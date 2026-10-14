import AppKit
import XCTest
import PaneFlipCore

final class PillPanelTests: XCTestCase {
    private final class NoBrands: BrandGlyphSource {
        var version = 0
        func glyph(forApp name: String) -> NSImage? { nil }
    }

    func testThePillCannotBeDraggedAway() {
        let panel = PillPanel(stack: ZoneStack(id: UUID()), settings: AppSettings(storage: StubSettingsStorage()),
                              iconFont: IconFont(brands: NoBrands()), select: { _ in }, hide: {})
        XCTAssertFalse(panel.isMovable)
        XCTAssertFalse(panel.isMovableByWindowBackground)
    }
}
