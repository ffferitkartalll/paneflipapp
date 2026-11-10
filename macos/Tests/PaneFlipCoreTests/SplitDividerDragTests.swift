import XCTest
import CoreGraphics
@testable import PaneFlipCore

final class SplitDividerDragTests: XCTestCase {
    private let line = SplitDivider(id: UUID(), sideBySide: true, parent: CGRect(x: 100, y: 0, width: 1000, height: 600), ratio: 0.5)

    func testALineNearAStepSticksToIt() {
        XCTAssertEqual(line.ratio(forPosition: 100 + 668), 2.0 / 3)
        XCTAssertEqual(line.ratio(forPosition: 100 + 500), 0.5)
    }

    func testALineBetweenStepsFollowsThePointer() {
        XCTAssertEqual(line.ratio(forPosition: 100 + 410), 0.41, accuracy: 0.0001)
    }

    func testNoZoneGetsSmallerThanATenth() {
        XCTAssertEqual(line.ratio(forPosition: 100 + 20), 0.1, accuracy: 0.0001)
        XCTAssertEqual(line.ratio(forPosition: 100 + 990), 0.9, accuracy: 0.0001)
    }

    func testTheRootAreaLeavesTheMarginOnEverySideWhateverLiesBeyond() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let withAreas = StripGeometry(strip: StripLayout(leading: [Overflow(width: 0.25, root: .leaf(UUID()))], root: .leaf(UUID()),
                                                         trailing: [Overflow(width: 0.25, root: .leaf(UUID()))]), screen: screen)
        XCTAssertEqual(withAreas.rootArea(margin: 20), CGRect(x: 20, y: 20, width: 960, height: 560), "every screen has its own margin, also on the side an area lies on")
        XCTAssertEqual(withAreas.rootArea(), screen)
        XCTAssertEqual(StripGeometry(strip: StripLayout(root: .leaf(UUID())), screen: screen).rootArea(margin: 20), CGRect(x: 20, y: 20, width: 960, height: 560))
    }
}

final class SplitDividerGapTests: XCTestCase {
    private func layout() -> (tree: LayoutNode, a: UUID, b: UUID, c: UUID, first: UUID, second: UUID) {
        let a = UUID(), b = UUID(), c = UUID(), first = UUID(), second = UUID()
        let tree = LayoutNode.split(id: first, sideBySide: true, ratio: 0.25, first: .leaf(a),
                                    second: .split(id: second, sideBySide: true, ratio: 2.0 / 3, first: .leaf(b), second: .leaf(c)))
        return (tree, a, b, c, first, second)
    }

    func testAQuarterAHalfAndAQuarterKeepTheirWidthsLessTheGapAndEqualRatiosGiveEqualZones() {
        let l = layout()
        let area = CGRect(x: 0, y: 0, width: 5120, height: 1000)
        let zones = Dictionary(uniqueKeysWithValues: l.tree.zones(in: area, gap: 80).map { ($0.id, $0.rect) })
        XCTAssertEqual(zones[l.a]?.width, 1220)
        XCTAssertEqual(zones[l.b]?.width, 2520)
        XCTAssertEqual(zones[l.c]?.width, 1220)
        XCTAssertEqual(zones[l.a]?.minX, 0, "no gap at the edge of the layout")
        XCTAssertEqual(zones[l.c]?.maxX, 5120)
        XCTAssertEqual(l.tree.zones(in: area, gap: 0).map(\.rect.width), [1280, 2560, 1280], "without a gap, the plain shares")
    }

    func testALineStandsInTheMiddleOfTheGapBetweenItsZones() {
        let l = layout()
        let area = CGRect(x: 0, y: 0, width: 5120, height: 1000)
        let zones = Dictionary(uniqueKeysWithValues: l.tree.zones(in: area, gap: 80).map { ($0.id, $0.rect) })
        let lines = Dictionary(uniqueKeysWithValues: l.tree.dividers(in: LayoutNode.lineArea(area, gap: 80)).map { ($0.id, $0.position) })
        XCTAssertEqual(lines[l.first] ?? 0, (zones[l.a]!.maxX + zones[l.b]!.minX) / 2, accuracy: 0.001)
        XCTAssertEqual(lines[l.second] ?? 0, (zones[l.b]!.maxX + zones[l.c]!.minX) / 2, accuracy: 0.001)
    }

    func testAGapAlsoLiesBetweenZonesStackedAboveEachOther() {
        let top = UUID(), bottom = UUID()
        let tree = LayoutNode.split(id: UUID(), sideBySide: false, ratio: 0.5, first: .leaf(top), second: .leaf(bottom))
        let zones = Dictionary(uniqueKeysWithValues: tree.zones(in: CGRect(x: 0, y: 0, width: 1000, height: 600), gap: 40).map { ($0.id, $0.rect) })
        XCTAssertEqual(zones[top], CGRect(x: 0, y: 0, width: 1000, height: 280))
        XCTAssertEqual(zones[bottom], CGRect(x: 0, y: 320, width: 1000, height: 280))
    }
}

final class StripEdgeGapTests: XCTestCase {
    func testTheScreensLayoutStandsToTheEdgesOfTheScreenWhateverLiesBeyondThem() {
        let root = UUID(), left = UUID(), right = UUID()
        let geometry = StripGeometry(strip: StripLayout(leading: [Overflow(width: 0.25, root: .leaf(left))], root: .leaf(root),
                                                        trailing: [Overflow(width: 0.25, root: .leaf(right))]),
                                     screen: CGRect(x: 0, y: 0, width: 1000, height: 600))
        let zones = Dictionary(uniqueKeysWithValues: geometry.zones(offset: 0, gap: 80, margin: 0).map { ($0.id, $0.rect) })
        XCTAssertEqual(zones[root], CGRect(x: 0, y: 0, width: 1000, height: 600), "no gap at the edges of the screen")
        XCTAssertEqual(zones[left]?.maxX, -80, "an area begins a gap beyond the screen")
        XCTAssertEqual(zones[right]?.minX, 1080)
        XCTAssertEqual(zones[left]?.minX, -330, "and runs to the far end of its width")
    }
}

final class LayoutNodeSidesTests: XCTestCase {
    func testTheSidesOfALineAreFoundAnywhereInTheTree() {
        let a = UUID(), b = UUID(), c = UUID(), outer = UUID(), inner = UUID()
        let tree = LayoutNode.split(id: outer, sideBySide: true, ratio: 0.5, first: .leaf(a),
                                    second: .split(id: inner, sideBySide: false, ratio: 0.5, first: .leaf(b), second: .leaf(c)))
        XCTAssertEqual(tree.sides(ofSplit: outer)?.first, .leaf(a))
        XCTAssertEqual(tree.sides(ofSplit: inner)?.second, .leaf(c))
        XCTAssertNil(tree.sides(ofSplit: UUID()))
    }
}

final class MovingLineTests: XCTestCase {
    private let area = CGRect(x: 0, y: 0, width: 4000, height: 1000)

    private func tree() -> (node: LayoutNode, first: UUID, second: UUID, row: UUID) {
        let first = UUID(), second = UUID(), row = UUID()
        let right = LayoutNode.split(id: second, sideBySide: true, ratio: 2.0 / 3, first: .leaf(UUID()),
                                     second: .split(id: row, sideBySide: false, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID())))
        return (.split(id: first, sideBySide: true, ratio: 0.25, first: .leaf(UUID()), second: right), first, second, row)
    }

    func testNoOtherLineMovesWhenOneIsMoved() {
        let t = tree()
        let before = Dictionary(uniqueKeysWithValues: t.node.dividers(in: area).map { ($0.id, $0.position) })
        let moved = t.node.movingLine(t.first, to: 0.4, in: area, least: 100)!
        XCTAssertEqual(moved.ratio, 0.4)
        let after = Dictionary(uniqueKeysWithValues: moved.node.dividers(in: area).map { ($0.id, $0.position) })
        XCTAssertEqual(after[t.first] ?? 0, 1600, accuracy: 0.001, "the line went where it was asked")
        XCTAssertEqual(after[t.second] ?? 0, before[t.second] ?? 1, accuracy: 0.001, "the line beside it kept its place")
        XCTAssertEqual(after[t.row] ?? 0, before[t.row] ?? 1, accuracy: 0.001, "and the line across the zones beside it")
    }

    func testALineStopsWhereItWouldPassTheNextOne() {
        let t = tree()
        let next = t.node.dividers(in: area).first { $0.id == t.second }!.position   // 3000
        let moved = t.node.movingLine(t.first, to: 0.9, in: area, least: 100)!
        let position = moved.node.dividers(in: area).first { $0.id == t.first }!.position
        XCTAssertEqual(position, next - 100, accuracy: 1, "a zone of the least size is left between the two")
    }

    func testALineReachesTheOuterEdgeWhereItsRectangleTouchesTheInnerOne() {
        let outer = CGRect(x: 0, y: 0, width: 1000, height: 400), inner = outer.insetBy(dx: 20, dy: 30)
        let line = SplitDivider(id: UUID(), sideBySide: true, parent: inner, ratio: 0.5).reaching(inner, to: outer)
        XCTAssertEqual(line.parent, CGRect(x: 20, y: 0, width: 960, height: 400))
        XCTAssertEqual(line.position, 500)
        let inside = SplitDivider(id: UUID(), sideBySide: true, parent: CGRect(x: 20, y: 100, width: 500, height: 100), ratio: 0.5).reaching(inner, to: outer)
        XCTAssertEqual(inside.parent.minY, 100)
        XCTAssertEqual(inside.parent.maxY, 200)
    }
}
