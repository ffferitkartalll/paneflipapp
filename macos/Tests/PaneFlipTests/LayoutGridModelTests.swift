import XCTest
import CoreGraphics
import PaneFlipCore

/// A layout of three screens, 900 × 600 each, on a display that shows the middle one: one zone on each, with two windows on the left, one in the middle (which has the
/// focus) and three on the right.
final class LayoutGridModelTests: XCTestCase {
    private let left = UUID(), middle = UUID(), right = UUID()
    private var model: LayoutGridModel!
    private var chosen: [(UUID, CGWindowID?)] = []

    private func zone(_ id: UUID, x: CGFloat, windows: [Int], front: Int) -> LayoutGridZone {
        let grid = ZoneWindowsModel()
        grid.cards = windows.map { IslandWindow(windowID: CGWindowID($0), bundleID: "b", name: "w", glyph: nil, glyphRevision: 0, absence: nil, isActive: $0 == front) }
        grid.size = CGSize(width: 900, height: 600)
        grid.gap = 12
        grid.tracksFocus = id == middle
        grid.highlighted = id == middle ? "w\(front)" : nil
        grid.onChoose = { [unowned self] card in chosen.append((id, card.windowID)) }
        return LayoutGridZone(id: id, rect: CGRect(x: x, y: 0, width: 900, height: 600), model: grid)
    }

    private var pointed: [String] { model.zones.compactMap(\.model.pointed) }

    override func setUp() {
        chosen = []
        model = LayoutGridModel()
        model.size = CGSize(width: 900, height: 600)
        model.rests = [-900, 0, 900]
        model.zones = [zone(left, x: -900, windows: [1, 2], front: 1), zone(middle, x: 0, windows: [3], front: 3), zone(right, x: 900, windows: [4, 5, 6], front: 4)]
        model.focused = middle
    }

    func testTheGridScrollsFromOneScreenToTheNextAndNoFurtherThanTheLayoutGoes() {
        XCTAssertEqual(model.rest(steps: 1), 900)
        model.shift = 900
        XCTAssertEqual(model.rest(steps: 1), 900, "nothing lies further right")
        XCTAssertEqual(model.rest(steps: -1), 0)
        model.shift = 0
        XCTAssertEqual(model.rest(steps: -1), -900)
        XCTAssertEqual(model.rest(steps: 0), 0)
    }

    func testOnlyTheZoneWithTheFocusHasTheCardWithTheFocus() {
        XCTAssertEqual(model.current?.card.id, "w3", "the card to be chosen is the card with the focus until the keys or the pointer say otherwise")
        XCTAssertEqual(model.zones.compactMap(\.model.highlighted), ["w3"])
    }

    func testTheArrowKeysGoFromCardToCardAcrossTheZonesAndTheGridScrollsToACardOutOfView() throws {
        func go(_ direction: ZoneDirection) throws -> CGFloat {
            let from = try XCTUnwrap(model.current)
            let next = try XCTUnwrap(model.neighbour(of: from, toward: direction))
            model.select(next)
            return model.shiftShowing(next)
        }
        XCTAssertEqual(try go(.right), 900, "the nearest card of the zone on the right is beyond the edge: the grid scrolls to its screen")
        XCTAssertEqual(pointed, ["w4"], "from the card of the zone that had the focus; one card is marked, in one zone")
        model.shift = 900
        XCTAssertEqual(try go(.right), 900, "in view: no scroll")
        XCTAssertEqual(pointed, ["w5"])
        _ = try go(.down)
        XCTAssertEqual(pointed, ["w6"], "the last row is not full: the card there is")
        XCTAssertEqual(try go(.left), 0, "the card of the middle zone: back to the middle screen")
        XCTAssertEqual(pointed, ["w3"])
        model.shift = 0
        XCTAssertEqual(try go(.left), -900, "on to the screen beyond the left edge")
        XCTAssertEqual(pointed, ["w2"])
        let last = try XCTUnwrap(model.current)
        XCTAssertNil(model.neighbour(of: last, toward: .up), "nothing lies above")
    }

    func testTheCardsInViewAreThoseWhoseMiddleIsOnTheDisplay() {
        XCTAssertEqual(model.places.filter(model.isInView).map(\.card.id), ["w3"])
        model.shift = 900
        XCTAssertEqual(model.places.filter(model.isInView).map(\.card.id), ["w4", "w5", "w6"])
    }

    func testTheZoneUnderThePointerIsTheOneItIsInElseTheNearestOne() {
        XCTAssertEqual(model.zone(at: CGPoint(x: 450, y: 300))?.id, middle)
        XCTAssertEqual(model.zone(at: CGPoint(x: 5, y: 300))?.id, middle, "the pointer at the edge, over no other zone")
        model.shift = 900
        XCTAssertEqual(model.zone(at: CGPoint(x: 450, y: 300))?.id, right, "the grid scrolled: the zone that stands there now")
        XCTAssertEqual(model.zone(at: CGPoint(x: 450, y: 900))?.id, right, "below every zone: the nearest one")
    }

    func testAZoneWithNoCardHasEveryPlaceOfItsGridEmpty() {
        let empty = zone(UUID(), x: 1800, windows: [], front: 0)
        XCTAssertEqual(empty.model.emptyCells.count, 4)
        XCTAssertEqual(model.zones[2].model.emptyCells.count, 1, "three cards in a grid of four places")
    }
}
