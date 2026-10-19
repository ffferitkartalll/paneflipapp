import XCTest
@testable import PaneFlipCore

final class StripLayoutTests: XCTestCase {
    private let screen = UUID(), left = UUID(), right = UUID()

    private func strip(leading: Double? = nil, trailing: Double? = nil) -> StripLayout {
        StripLayout(leading: leading.map { Overflow(width: $0, root: .leaf(left)) }, root: .leaf(screen),
                    trailing: trailing.map { Overflow(width: $0, root: .leaf(right)) })
    }

    private func roundTrip(_ s: StripLayout) -> StripLayout {
        StripLayout(composite: s.composite, leadingID: s.leading?.id, trailingID: s.trailing?.id)
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
            XCTAssertEqual(back.leading?.root, s.leading?.root)
            XCTAssertEqual(back.trailing?.root, s.trailing?.root)
            XCTAssertEqual(back.leading?.width ?? 0, s.leading?.width ?? 0, accuracy: 0.0001)
            XCTAssertEqual(back.trailing?.width ?? 0, s.trailing?.width ?? 0, accuracy: 0.0001)
        }
    }

    func testDraggingTheLineBetweenScreenAndOverflowChangesItsWidth() {
        let s = strip(trailing: 0.25)
        let widened = s.composite.settingRatio(s.trailing!.id, 0.5)
        let back = StripLayout(composite: widened, leadingID: nil, trailingID: s.trailing!.id)
        XCTAssertEqual(back.trailing?.width ?? 0, 1, accuracy: 0.0001)
    }

    func testZonesMergeOnlyWithinTheirOwnPart() {
        var s = strip(trailing: 0.25)
        let extra = UUID()
        let divided = s.trailing!.root.splitting(right, sideBySide: false, ratio: 0.5)
        s.trailing?.root = divided
        let second = s.trailing!.root.leafIDs[1]
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
        XCTAssertNil(decoded.leading)
        XCTAssertNil(decoded.trailing)

        var withOverflow = layout
        withOverflow.trailing = Overflow(width: 0.25, root: .leaf(right))
        let again = try JSONDecoder().decode(NamedLayout.self, from: JSONEncoder().encode(withOverflow))
        XCTAssertEqual(again.trailing, withOverflow.trailing)
    }

    func testZonesAreNumberedFromTheScreenOutwards() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        func two(_ x: UUID, _ y: UUID) -> LayoutNode { .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(x), second: .leaf(y)) }
        let s = StripLayout(leading: Overflow(root: two(a, b)), root: two(c, d), trailing: Overflow(root: .leaf(e)))
        XCTAssertTrue(s.position(of: a)! == (.leading, 2), "the far one of the left area is -2")
        XCTAssertTrue(s.position(of: b)! == (.leading, 1), "the nearest to the screen is -1")
        XCTAssertTrue(s.position(of: c)! == (.screen, 1))
        XCTAssertTrue(s.position(of: d)! == (.screen, 2))
        XCTAssertTrue(s.position(of: e)! == (.trailing, 1))
        XCTAssertNil(s.position(of: UUID()))
    }
}
