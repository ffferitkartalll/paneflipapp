import XCTest
@testable import PaneFlipCore

final class StripLayoutTests: XCTestCase {
    private let screen = UUID(), left = UUID(), right = UUID()

    private func strip(leading: Double? = nil, trailing: Double? = nil) -> StripLayout {
        StripLayout(leading: leading.map { [Overflow(width: $0, root: .leaf(left))] } ?? [], root: .leaf(screen),
                    trailing: trailing.map { [Overflow(width: $0, root: .leaf(right))] } ?? [])
    }

    private func roundTrip(_ s: StripLayout) -> StripLayout {
        StripLayout(composite: s.composite, leadingIDs: s.leading.map(\.id), trailingIDs: s.trailing.map(\.id))
    }

    func testKeepingTheAreasOfAnotherStripChangesOnlyTheScreen() {
        let kept = strip(leading: 0.5, trailing: 0.25)
        let edited = StripLayout(root: .leaf(UUID()))
        let result = edited.keepingAreas(of: kept)
        XCTAssertEqual(result.root, edited.root)
        XCTAssertEqual(result.leading, kept.leading)
        XCTAssertEqual(result.trailing, kept.trailing)
    }

    func testTheCompositeGivesEachPartItsShareOfTheWidth() {
        let s = strip(leading: 0.5, trailing: 0.25)
        XCTAssertEqual(s.totalWidth, 1.75)
        let zones = s.composite.zones(in: CGRect(x: 0, y: 0, width: 1750, height: 100))
        XCTAssertEqual(zones.first { $0.id == left }?.rect.width ?? 0, 500, accuracy: 0.001)
        XCTAssertEqual(zones.first { $0.id == screen }?.rect.width ?? 0, 1000, accuracy: 0.001)
        XCTAssertEqual(zones.first { $0.id == right }?.rect.width ?? 0, 250, accuracy: 0.001)
    }

    func testTheCompositeTurnsBackIntoTheSameStrip() {
        for s in [strip(), strip(trailing: 0.25), strip(leading: 0.4), strip(leading: 0.5, trailing: 0.25)] {
            let back = roundTrip(s)
            XCTAssertEqual(back.root, s.root)
            XCTAssertEqual(back.leading.map(\.root), s.leading.map(\.root))
            XCTAssertEqual(back.trailing.map(\.root), s.trailing.map(\.root))
            XCTAssertEqual(back.leadingWidth, s.leadingWidth, accuracy: 0.0001)
            XCTAssertEqual(back.trailingWidth, s.trailingWidth, accuracy: 0.0001)
        }
    }

    func testDraggingTheLineBetweenScreenAndOverflowChangesItsWidth() {
        let s = strip(trailing: 0.25)
        let widened = s.composite.settingRatio(s.trailing[0].id, 0.5)
        let back = StripLayout(composite: widened, leadingIDs: [], trailingIDs: [s.trailing[0].id])
        XCTAssertEqual(back.trailingWidth, 1, accuracy: 0.0001)
    }

    func testZonesMergeOnlyWithinTheirOwnPart() {
        var s = strip(trailing: 0.25)
        let extra = UUID()
        let divided = s.trailing[0].root.splitting(right, sideBySide: false, ratio: 0.5)
        s.trailing[0].root = divided
        let second = s.trailing[0].root.leafIDs[1]
        XCTAssertNotNil(s.merging(right, second))
        XCTAssertNil(s.merging(screen, right), "a zone cannot reach across the edge of the screen")
        XCTAssertNil(s.merging(screen, extra))
    }

    func testPartsAreTold() {
        let s = strip(leading: 0.25, trailing: 0.25)
        XCTAssertEqual([s.part(of: left), s.part(of: screen), s.part(of: right)], [.leading, .screen, .trailing])
        XCTAssertNil(s.part(of: UUID()))
        XCTAssertEqual(s.zoneIDs, [left, screen, right])
    }

    func testALayoutWrittenBeforeOverflowsHasNone() throws {
        let layout = NamedLayout(name: "x", root: .leaf(screen))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as! [String: Any]
        json["leading"] = nil
        json["trailing"] = nil
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.leading.isEmpty)
        XCTAssertTrue(decoded.trailing.isEmpty)

        var withOverflow = layout
        withOverflow.trailing = [Overflow(width: 0.25, root: .leaf(right)), Overflow(width: 0.5, root: .leaf(UUID()))]
        let again = try JSONDecoder().decode(NamedLayout.self, from: JSONEncoder().encode(withOverflow))
        XCTAssertEqual(again.trailing, withOverflow.trailing)
    }

    func testAFileWithOneAreaPerSideStillLoads() throws {
        let area = Overflow(width: 0.25, root: .leaf(right))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(NamedLayout(name: "x", root: .leaf(screen)))) as! [String: Any]
        json["trailing"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(area))   // the single area an older file holds
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.trailing, [area])
    }

    func testAreasFollowOneAnotherOnEachSideAndTheCompositeTurnsBack() {
        let l1 = UUID(), l2 = UUID(), r1 = UUID(), r2 = UUID(), r3 = UUID()
        let s = StripLayout(leading: [Overflow(width: 0.5, root: .leaf(l1)), Overflow(width: 1, root: .leaf(l2))], root: .leaf(screen),
                            trailing: [Overflow(width: 0.25, root: .leaf(r1)), Overflow(width: 0.25, root: .leaf(r2)),
                                       Overflow(width: 2, root: .leaf(r3))])
        XCTAssertEqual(s.totalWidth, 5)
        XCTAssertEqual(s.zoneIDs, [l2, l1, screen, r1, r2, r3], "in order across the strip")
        XCTAssertTrue(s.position(of: l1)! == (.leading, 1) && s.position(of: l2)! == (.leading, 2))
        XCTAssertTrue(s.position(of: r1)! == (.trailing, 1) && s.position(of: r3)! == (.trailing, 3))

        let back = roundTrip(s)
        XCTAssertEqual(back.leading.map(\.root), s.leading.map(\.root))
        XCTAssertEqual(back.trailing.map(\.root), s.trailing.map(\.root))
        for (found, wanted) in zip(back.leading.map(\.width) + back.trailing.map(\.width), [0.5, 1, 0.25, 0.25, 2]) {
            XCTAssertEqual(found, wanted, accuracy: 0.0001)
        }
        XCTAssertEqual(back.leading.map(\.id), s.leading.map(\.id))

        let zones = s.composite.zones(in: CGRect(x: 0, y: 0, width: 5000, height: 100))
        XCTAssertEqual(zones.first { $0.id == l2 }?.rect.minX ?? -1, 0, accuracy: 0.001, "the outermost area is first on the left")
        XCTAssertEqual(zones.first { $0.id == screen }?.rect.minX ?? 0, 1500, accuracy: 0.001)
        XCTAssertEqual(zones.first { $0.id == r3 }?.rect.width ?? 0, 2000, accuracy: 0.001)
    }

    func testZonesAreNumberedFromTheScreenOutwards() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        func two(_ x: UUID, _ y: UUID) -> LayoutNode { .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(x), second: .leaf(y)) }
        let s = StripLayout(leading: [Overflow(root: two(a, b))], root: two(c, d), trailing: [Overflow(root: .leaf(e))])
        XCTAssertTrue(s.position(of: a)! == (.leading, 2), "the far one of the left area is -2")
        XCTAssertTrue(s.position(of: b)! == (.leading, 1), "the nearest to the screen is -1")
        XCTAssertTrue(s.position(of: c)! == (.screen, 1))
        XCTAssertTrue(s.position(of: d)! == (.screen, 2))
        XCTAssertTrue(s.position(of: e)! == (.trailing, 1))
        XCTAssertNil(s.position(of: UUID()))
    }

    func testAViewOfOneScreenRestsAtTheScreenAndAtTheFarEdgeOfEachArea() {
        XCTAssertEqual(StripLayout(root: .leaf(screen)).areaRests, [0])
        let s = StripLayout(leading: [Overflow(width: 0.5, root: .leaf(left)), Overflow(width: 1, root: .leaf(UUID()))], root: .leaf(screen),
                            trailing: [Overflow(width: 1, root: .leaf(right)), Overflow(width: 0.25, root: .leaf(UUID()))])
        XCTAssertEqual(s.areaRests, [-1.5, -0.5, 0, 1, 1.25], "from the left to the right")
        XCTAssertEqual(s.nearestAreaRestIndex(to: 0.4), 2)
        XCTAssertEqual(s.nearestAreaRestIndex(to: -1), 0, "a tie goes to the left")
    }

    func testTheAreaAViewRestsAtIsTheOneWhoseFarEdgeItStandsAt() {
        let near = Overflow(width: 1, root: .leaf(right)), far = Overflow(width: 1, root: .leaf(UUID())), left = Overflow(width: 0.5, root: .leaf(left))
        let s = StripLayout(leading: [left], root: .leaf(screen), trailing: [near, far])
        XCTAssertNil(s.area(at: 0), "the screen's own layout is no area")
        XCTAssertEqual(s.area(at: 1)?.id, near.id)
        XCTAssertEqual(s.area(at: 2)?.id, far.id)
        XCTAssertEqual(s.area(at: -0.5)?.id, left.id)
        XCTAssertNil(s.area(at: 0.7), "between two rests")
    }

    func testEveryLineBetweenZonesIsARestPositionOnTheScreenAndInTheAreas() {
        let main = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.4, first: .leaf(UUID()), second: .leaf(UUID()))
        let area = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID()))
        let s = StripLayout(root: main, trailing: [Overflow(width: 1, root: area), Overflow(width: 1, root: .leaf(UUID()))])

        XCTAssertEqual(s.zoneEdges, [0, 0.4, 1, 1.5, 2, 3])
        // A line at the left edge of the screen (the screen's own, the start of an area, the middle of the first area, ...) or at its
        // right edge (...), and no further than the strip goes.
        XCTAssertEqual(s.rests, [0, 0.4, 0.5, 1, 1.5, 2])
        XCTAssertEqual(StripLayout(root: .leaf(screen)).rests, [0])
    }

    func testAnAreaThatIsAWholeZoneStillRestsAtItsFarEdge() {
        // The layouts of before: every area one zone, a quarter of a screen wide.
        XCTAssertEqual(strip(leading: 0.25, trailing: 0.25).rests, [-0.25, 0, 0.25])
    }

    func testZonesThatDoNotShareTheirLinesGiveALineEach() {
        // A column split into two rows has no line of its own, but the column beside it is split at another place.
        let left = LayoutNode.split(id: UUID(), sideBySide: false, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID()))
        let right = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.3, first: .leaf(UUID()), second: .leaf(UUID()))
        let main = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.5, first: left, second: right)
        XCTAssertEqual(StripLayout(root: main).zoneEdges, [0, 0.5, 0.65, 1])
    }
}
