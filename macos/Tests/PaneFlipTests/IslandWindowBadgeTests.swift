import XCTest

final class IslandWindowBadgeTests: XCTestCase {
    private func card(_ badge: String?) -> IslandWindow {
        var card = IslandWindow(windowID: 1, bundleID: "x", name: "X", glyph: nil, glyphRevision: 0, absence: nil, isActive: false)
        card.badge = badge
        return card
    }

    func testABadgeIsShownAsTheDockHasItAndALargeNumberIsCut() {
        XCTAssertNil(card(nil).badgeText)
        XCTAssertNil(card("").badgeText)
        XCTAssertEqual(card("3").badgeText, "3")
        XCTAssertEqual(card("99").badgeText, "99")
        XCTAssertEqual(card("1204").badgeText, "99+")
        XCTAssertEqual(card("•").badgeText, "•")
    }
}
