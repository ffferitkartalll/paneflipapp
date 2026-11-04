import XCTest
@testable import PaneFlipCore

final class StripGeometryTests: XCTestCase {
    private let screenRect = CGRect(x: 0, y: 0, width: 1000, height: 400)
    private let left = UUID(), middle = UUID(), right = UUID()

    private func geometry(leading: Double? = nil, trailing: Double? = nil) -> StripGeometry {
        StripGeometry(strip: StripLayout(leading: leading.map { [Overflow(width: $0, root: .leaf(left))] } ?? [], root: .leaf(middle),
                                         trailing: trailing.map { [Overflow(width: $0, root: .leaf(right))] } ?? []), screen: screenRect)
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
        let g = StripGeometry(strip: StripLayout(root: root, trailing: [Overflow(width: 0.25, root: .leaf(right))]), screen: screenRect)
        XCTAssertEqual(g.zones(offset: 249).first { $0.id == first }?.isOnScreen, false, "a pixel showing: a window cannot rest like that")
        XCTAssertEqual(g.zones(offset: 243).first { $0.id == first }?.isOnScreen, false, "seven pixels showing")
        XCTAssertEqual(g.zones(offset: 242).first { $0.id == first }?.isOnScreen, true, "eight pixels showing")
        XCTAssertEqual(g.zones(offset: 250).first { $0.id == second }?.isOnScreen, true)
    }

    func testAGapLiesBetweenTheScreenAndItsFirstOverflowAndTheScrollingSkipsIt() {
        let g = geometry(leading: 0.25, trailing: 0.25)
        let gapped = StripGeometry(strip: g.strip, screen: g.screen, gap: 8)
        XCTAssertEqual(gapped.rests, [-258, 0, 258], "the rests are the far edges of the areas, the gap before each of them counted")

        let peek = gapped.zones(offset: 258, gap: 8)
        let screenZone = peek.first { $0.id == middle }!.rect, area = peek.first { $0.id == right }!.rect
        XCTAssertEqual(area.minX - screenZone.maxX, 8, "the gap of the zones lies between the screens")
        XCTAssertEqual(area.maxX, 1000, "at the rest the area's far edge is at the screen's")

        let rest = gapped.zones(offset: 0, gap: 8).first { $0.id == middle }!.rect
        XCTAssertEqual(rest, CGRect(x: 0, y: 0, width: 1000, height: 400), "no gap at the edges of the screen at rest, an overflow beyond them or not")

        let left = gapped.zones(offset: -258, gap: 8)
        XCTAssertEqual(left.first { $0.id == middle }!.rect.minX - left.first { $0.id == self.left }!.rect.maxX, 8)
    }

    func testTheScreenAViewRestsAtIsFoundByItsOffsetAndNilBetweenTwo() {
        let g = StripGeometry(strip: StripLayout(leading: [Overflow(width: 1, root: .leaf(UUID()))], root: .leaf(middle),
                                                 trailing: [Overflow(width: 1, root: .leaf(UUID())), Overflow(width: 1, root: .leaf(UUID()))]), screen: screenRect, gap: 40)
        XCTAssertEqual(g.screen(restingAt: 0), .own)
        XCTAssertEqual(g.screen(restingAt: 1040), .trailing(0))
        XCTAssertEqual(g.screen(restingAt: 2080), .trailing(1), "a gap before each area is counted")
        XCTAssertEqual(g.screen(restingAt: -1040), .leading(0))
        XCTAssertNil(g.screen(restingAt: 500))
        XCTAssertNil(g.screen(restingAt: 1000), "the gap is passed through, not rested at")
    }

    func testAViewThatRestedAtAScreenRestsAtItAgainWhenTheGapOrTheMarginChanges() {
        let strip = StripLayout(leading: [Overflow(width: 1, root: .leaf(UUID()))], root: .leaf(middle),
                                trailing: [Overflow(width: 1, root: .leaf(UUID())), Overflow(width: 1, root: .leaf(UUID()))])
        let now = StripGeometry(strip: strip, screen: screenRect, gap: 40, margin: 0)
        XCTAssertEqual(now.restOffset(of: .trailing(1)), 2080)
        XCTAssertEqual(now.restOffset(of: .leading(0)), -1040)
        XCTAssertNil(now.restOffset(of: .trailing(2)), "no such area")
        // It rested at the second area when the gap was 8: now, with 40, that area's rest is elsewhere.
        XCTAssertEqual(now.offset(keepingScreenOf: 2016, whenGapWas: 8, marginWas: 0), 2080)
        XCTAssertEqual(now.offset(keepingScreenOf: 0, whenGapWas: 8, marginWas: 0), 0)
        XCTAssertNil(now.offset(keepingScreenOf: 500, whenGapWas: 8, marginWas: 0), "between two screens it stays where it is")
    }

    func testAnAreaAsWideAsTheScreenFillsTheScreenExactlyAtItsRest() {
        let area = UUID()
        let g = StripGeometry(strip: StripLayout(root: .leaf(middle), trailing: [Overflow(width: 1, root: .leaf(area))]), screen: screenRect, gap: 40)
        XCTAssertEqual(g.rests.last, 1040)
        XCTAssertEqual(g.zones(offset: 1040, gap: 40).first { $0.id == area }?.rect, screenRect, "the gap is skipped, the area stands where the screen is")
    }

    func testEveryScreenOfTheStripHasItsOwnMarginOnAllSides() {
        let g = geometry(trailing: 0.25)

        let rest = g.zones(offset: 0, margin: 20).first { $0.id == middle }!.rect
        XCTAssertEqual(rest, CGRect(x: 20, y: 20, width: 960, height: 360), "also on the side an overflow lies on")

        let peek = g.zones(offset: 230, margin: 20)
        XCTAssertEqual(peek.first { $0.id == right }!.rect, CGRect(x: 770, y: 20, width: 210, height: 360), "the overflow at its rest has it on both sides")
        XCTAssertEqual(peek.first { $0.id == middle }!.rect.maxX, 750, "between the two lie the margin, not two of them")
    }

    func testBetweenScreensThereIsTheGapOrTheMarginWhicheverIsMoreAndScrollingSkipsIt() {
        let area = UUID()
        let strip = StripLayout(root: .leaf(middle), trailing: [Overflow(width: 1, root: .leaf(area))])
        func between(gap: CGFloat, margin: CGFloat) -> (seen: CGFloat, rest: CGFloat?) {
            let g = StripGeometry(strip: strip, screen: screenRect, gap: gap, margin: margin)
            let zones = g.zones(offset: 0)
            return (zones.first { $0.id == area }!.rect.minX - zones.first { $0.id == middle }!.rect.maxX, g.rests.last)
        }
        XCTAssertEqual(between(gap: 40, margin: 0).seen, 40)
        XCTAssertEqual(between(gap: 40, margin: 0).rest, 1040)
        XCTAssertEqual(between(gap: 40, margin: 10).seen, 40, "the margin is less than the gap: the gap is seen")
        XCTAssertEqual(between(gap: 40, margin: 10).rest, 1020, "the space of the screens is the gap less the margins")
        XCTAssertEqual(between(gap: 40, margin: 40).seen, 40, "a margin as wide as the gap leaves the gap, not twice it")
        XCTAssertEqual(between(gap: 40, margin: 40).rest, 960, "the margins of the two screens overlap")
        XCTAssertEqual(between(gap: 8, margin: 10).seen, 10, "the margin is more than the gap: it decides")
        XCTAssertEqual(between(gap: 8, margin: 10).rest, 990)
    }

    func testAreasFollowOneAnotherAndTheirFarEdgesAreRestPositions() {
        let near = UUID(), far = UUID(), leftNear = UUID(), leftFar = UUID()
        let g = StripGeometry(strip: StripLayout(leading: [Overflow(width: 0.5, root: .leaf(leftNear)), Overflow(width: 1, root: .leaf(leftFar))],
                                                 root: .leaf(middle),
                                                 trailing: [Overflow(width: 0.25, root: .leaf(near)), Overflow(width: 2, root: .leaf(far))]),
                              screen: screenRect)
        let gapped8 = StripGeometry(strip: g.strip, screen: screenRect, gap: 8)
        XCTAssertEqual(gapped8.range, -1516 ... 2266, "a gap before each area")
        XCTAssertEqual(gapped8.rests, [-1516, -508, 0, 258, 2266])

        XCTAssertEqual(g.range, -1500 ... 2250)
        XCTAssertEqual(g.rests, [-1500, -500, 0, 250, 2250], "the screen's own layout and the far edge of each area: screens, not the lines between zones")

        let at = g.zones(offset: 0)
        XCTAssertEqual(at.map(\.id), [leftFar, leftNear, middle, near, far], "in order across the strip")
        XCTAssertEqual(at.first { $0.id == far }?.rect, CGRect(x: 1250, y: 0, width: 2000, height: 400))
        XCTAssertEqual(at.first { $0.id == leftFar }?.rect, CGRect(x: -1500, y: 0, width: 1000, height: 400))

        let end = g.zones(offset: 2250)
        XCTAssertEqual(end.first { $0.id == far }?.rect.maxX, 1000, "the last area is right-aligned at the rest")
        XCTAssertEqual(end.map(\.isOnScreen), [false, false, false, false, true])

        let gapped = g.zones(offset: 0, gap: 8, margin: 2)
        XCTAssertEqual(gapped.first { $0.id == near }!.rect.minX - gapped.first { $0.id == middle }!.rect.maxX, 8, "beside the screen too")
        XCTAssertEqual(gapped.first { $0.id == far }!.rect.minX - gapped.first { $0.id == near }!.rect.maxX, 8, "between one area and the next too")
        XCTAssertEqual(gapped.first { $0.id == far }!.rect.maxX, 3256, "the margin at the far end of the last area")
    }
}
