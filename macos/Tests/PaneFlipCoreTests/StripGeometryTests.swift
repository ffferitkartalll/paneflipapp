import XCTest
@testable import PaneFlipCore

final class StripGeometryTests: XCTestCase {
    private let screenRect = CGRect(x: 0, y: 0, width: 1000, height: 400)
    private let left = UUID(), middle = UUID(), right = UUID()

    private func geometry(leading: Double? = nil, trailing: Double? = nil) -> StripGeometry {
        StripGeometry(strip: StripLayout(leading: leading.map { Overflow(width: $0, root: .leaf(left)) }, root: .leaf(middle),
                                         trailing: trailing.map { Overflow(width: $0, root: .leaf(right)) }), screen: screenRect)
    }

    func testTheOverflowsLieBesideTheScreenAndScrollingMovesEverything() {
        let g = geometry(leading: 0.25, trailing: 0.25)
        var zones = g.zones(offset: 0)
        XCTAssertEqual(zones.first { $0.id == left }?.rect, CGRect(x: -250, y: 0, width: 250, height: 400))
        XCTAssertEqual(zones.first { $0.id == right }?.rect, CGRect(x: 1000, y: 0, width: 250, height: 400))
        XCTAssertEqual(zones.map(\.isOnScreen), [false, true, false])

        zones = g.zones(offset: 250)
        XCTAssertEqual(zones.first { $0.id == right }?.rect.minX, 750)
        XCTAssertEqual(zones.map(\.isOnScreen), [false, true, true], "the right overflow came in, the left one is out of sight")
    }

    func testTheOffsetStaysWithinTheOverflows() {
        let g = geometry(leading: 0.1, trailing: 0.25)
        XCTAssertEqual(g.range, -100 ... 250)
        XCTAssertEqual(g.clamped(900), 250)
        XCTAssertEqual(g.clamped(-900), -100)
        XCTAssertEqual(geometry().clamped(40), 0, "no overflow, no scrolling")
    }

    func testScrollingComesToRestAtTheEndsAndTheScreensOwnLayout() {
        let g = geometry(leading: 0.25, trailing: 0.25)
        XCTAssertEqual(g.rests, [-250, 0, 250])
        XCTAssertEqual(geometry(leading: nil, trailing: 0.25).rests, [0, 250])
    }

    func testAZoneShowingOnlyAFewPixelsIsOutOfSight() {
        let first = UUID(), second = UUID()
        let root = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.25, first: .leaf(first), second: .leaf(second))
        let g = StripGeometry(strip: StripLayout(root: root, trailing: Overflow(width: 0.25, root: .leaf(right))), screen: screenRect)
        XCTAssertEqual(g.zones(offset: 249).first { $0.id == first }?.isOnScreen, false, "a pixel showing: a window cannot rest like that")
        XCTAssertEqual(g.zones(offset: 243).first { $0.id == first }?.isOnScreen, false, "seven pixels showing")
        XCTAssertEqual(g.zones(offset: 242).first { $0.id == first }?.isOnScreen, true, "eight pixels showing")
        XCTAssertEqual(g.zones(offset: 250).first { $0.id == second }?.isOnScreen, true)
    }

    func testTheGapLiesBetweenTheScreenAndAnOverflowAtAllTimes() {
        let g = geometry(leading: 0.25, trailing: 0.25)

        let peek = g.zones(offset: 250, gap: 8)
        let screenZone = peek.first { $0.id == middle }!.rect, area = peek.first { $0.id == right }!.rect
        XCTAssertEqual(area.minX - screenZone.maxX, 8)
        XCTAssertEqual(area.maxX, 1000, "the far edge stays where it was")

        let rest = g.zones(offset: 0, gap: 8).first { $0.id == middle }!.rect
        XCTAssertEqual(rest, CGRect(x: 4, y: 0, width: 992, height: 400), "half the gap on the sides that meet an overflow")

        let left = g.zones(offset: -250, gap: 8)
        XCTAssertEqual(left.first { $0.id == middle }!.rect.minX - left.first { $0.id == self.left }!.rect.maxX, 8)
    }

    func testTheMarginRunsRoundTheWholeStripNotBetweenTheScreenAndItsOverflow() {
        let g = geometry(trailing: 0.25)

        let rest = g.zones(offset: 0, margin: 20).first { $0.id == middle }!.rect
        XCTAssertEqual(rest, CGRect(x: 20, y: 20, width: 980, height: 360), "no margin on the side an overflow lies on")

        let peek = g.zones(offset: 250, margin: 20)
        XCTAssertEqual(peek.first { $0.id == right }!.rect, CGRect(x: 750, y: 20, width: 230, height: 360), "the far end has it")
        XCTAssertEqual(peek.first { $0.id == middle }!.rect.maxX, 750, "and nothing lies between the two")
    }
}
