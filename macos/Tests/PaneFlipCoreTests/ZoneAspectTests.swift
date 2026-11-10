import XCTest
@testable import PaneFlipCore

/// Zones that keep their width-to-height ratio while the lines of a layout move.
final class ZoneAspectTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let a = UUID(), b = UUID(), c = UUID(), column = UUID(), row = UUID()
    private let laid: LayoutNode.Laid = { node in node.zones(in: CGRect(x: 0, y: 0, width: 1600, height: 1000)) }

    /// A on the left, B above C on the right.
    private var tree: LayoutNode {
        .split(id: column, sideBySide: true, ratio: 0.5, first: .leaf(a),
               second: .split(id: row, sideBySide: false, ratio: 0.5, first: .leaf(b), second: .leaf(c)))
    }

    private func size(_ node: LayoutNode, _ zone: UUID) -> CGSize { node.zones(in: rect).first { $0.id == zone }!.rect.size }

    func testAZoneIsBroughtToItsRatioByMovingTheLineBelowIt() throws {
        let node = try XCTUnwrap(tree.settingAspect(of: b, to: ZoneAspect(16, 9), among: [:], in: rect, least: 100, laid: laid))
        XCTAssertEqual(size(node, b).width / size(node, b).height, 16.0 / 9, accuracy: 0.001)
        XCTAssertEqual(size(node, a).width, 800, "the column did not move")
    }

    func testTheLineBesideALockedZoneTakesTheLineBelowItAlong() throws {
        let locked = try XCTUnwrap(tree.settingAspect(of: b, to: ZoneAspect(16, 9), among: [:], in: rect, least: 100, laid: laid))
        let moved = try XCTUnwrap(locked.movingLine(column, to: 0.6, in: rect, least: 100, aspects: [b: ZoneAspect(16, 9)], laid: laid))
        XCTAssertEqual(moved.ratio, 0.6, accuracy: 1e-9)
        XCTAssertEqual(size(moved.node, b).width, 640, accuracy: 0.01)
        XCTAssertEqual(size(moved.node, b).width / size(moved.node, b).height, 16.0 / 9, accuracy: 0.001)
    }

    func testALineStopsWhereALockedZoneHasNoLineToFollowIt() throws {
        // A is 800 × 1000 (4:5) along the whole height: nothing can change its height, so its width cannot change either.
        let moved = try XCTUnwrap(tree.movingLine(column, to: 0.6, in: rect, least: 100, aspects: [a: ZoneAspect(4, 5)], laid: laid))
        XCTAssertEqual(moved.ratio, 0.5, accuracy: 0.001)
        XCTAssertEqual(size(moved.node, a).width, 800, accuracy: 1)
    }

    func testARatioThatNoLineCanGiveIsRefused() {
        XCTAssertNil(tree.settingAspect(of: a, to: ZoneAspect(16, 9), among: [:], in: rect, least: 100, laid: laid))
    }

    func testWithoutLockedZonesALineMovesAsBefore() throws {
        let plain = try XCTUnwrap(tree.movingLine(column, to: 0.7, in: rect, least: 100))
        let same = try XCTUnwrap(tree.movingLine(column, to: 0.7, in: rect, least: 100, aspects: [:], laid: laid))
        XCTAssertEqual(plain.node, same.node)
    }

    func testRatiosAreKeptWithTheLayoutAndItsCopy() throws {
        var layout = NamedLayout(name: "L", root: tree)
        layout.zoneAspects[b] = ZoneAspect(16, 9)
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONEncoder().encode(layout))
        XCTAssertEqual(decoded.zoneAspects, [b: ZoneAspect(16, 9)])
        let copy = layout.copy(named: "C")
        XCTAssertEqual(copy.zoneAspects.values.map(\.self), [ZoneAspect(16, 9)])
        XCTAssertTrue(Set(copy.zoneAspects.keys).isDisjoint(with: [a, b, c]))
    }
}
