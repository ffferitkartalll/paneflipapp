import XCTest
@testable import PaneFlipCore

final class LayoutNodeTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1000, height: 400)

    private func split(_ side: Bool, _ a: LayoutNode, _ b: LayoutNode, ratio: Double = 0.5) -> LayoutNode {
        .split(id: UUID(), sideBySide: side, ratio: ratio, first: a, second: b)
    }

    func testSplittingKeepsFirstHalfIdentity() {
        let id = UUID()
        let tree = LayoutNode.leaf(id).splitting(id, sideBySide: true, ratio: 0.5)
        XCTAssertEqual(tree.leafIDs.count, 2)
        XCTAssertEqual(tree.leafIDs.first, id)
    }

    func testGapAppliesBetweenZonesOnly() {
        let tree = split(true, .leaf(UUID()), .leaf(UUID()))
        let zones = tree.zones(in: area, gap: 10)
        XCTAssertEqual(zones[0].rect.minX, 0)
        XCTAssertEqual(zones[1].rect.maxX, 1000)
        XCTAssertEqual(zones[1].rect.minX - zones[0].rect.maxX, 10, accuracy: 0.001)
    }

    /// The case that went wrong: merging two zones that sit on opposite sides of the root split.
    func testMergingAcrossRootSplitMergesOnlyThoseTwo() {
        let z1 = UUID(), z2 = UUID(), z3 = UUID(), z4 = UUID(), z5 = UUID(), z6 = UUID()
        let tree = split(true,
                         split(true, split(false, .leaf(z1), .leaf(z2)), .leaf(z3)),
                         split(true, .leaf(z4), split(false, .leaf(z5), .leaf(z6))))
        let merged = tree.merging(z3, z4, in: area)
        XCTAssertNotNil(merged)
        let zones = merged!.zones(in: area)
        XCTAssertEqual(zones.count, 5)
        let middle = zones.first { $0.id == z3 }!.rect
        XCTAssertEqual(middle, CGRect(x: 250, y: 0, width: 500, height: 400))
        XCTAssertFalse(zones.contains { $0.id == z4 })
    }

    func testMergingNonRectangularUnionIsRejected() {
        let z1 = UUID(), z2 = UUID(), z3 = UUID()
        let tree = split(true, split(false, .leaf(z1), .leaf(z2)), .leaf(z3))
        XCTAssertNil(tree.merging(z1, z3, in: area))
        XCTAssertNil(tree.merging(z2, z3, in: area))
    }

    func testCollapsingJoinsBothSides() {
        let id = UUID()
        let a = UUID(), b = UUID()
        let tree = LayoutNode.split(id: id, sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b))
        XCTAssertEqual(tree.collapsing(id), .leaf(a))
    }

    func testSettingRatioChangesOnlyTheTargetSplit() {
        let id = UUID()
        let tree = LayoutNode.split(id: id, sideBySide: true, ratio: 0.5, first: .leaf(UUID()), second: .leaf(UUID()))
        let zones = tree.settingRatio(id, 0.25).zones(in: area)
        XCTAssertEqual(zones[0].rect.width, 250, accuracy: 0.001)
    }

    func testCodableRoundTrip() throws {
        let tree = split(false, .leaf(UUID()), split(true, .leaf(UUID()), .leaf(UUID())))
        let data = try JSONEncoder().encode(tree)
        XCTAssertEqual(try JSONDecoder().decode(LayoutNode.self, from: data), tree)
    }

    func testReusingPutsTheGivenZonesInTreeOrderAndKeepsTheRestNew() {
        let a = UUID(), b = UUID()
        let shape = LayoutPreset.all[1].root   // three columns
        let ids = shape.leafIDs
        let result = shape.reusing([a, b])
        XCTAssertEqual(Array(result.leafIDs.prefix(2)), [a, b])
        XCTAssertEqual(result.leafIDs[2], ids[2])
        XCTAssertEqual(shape.reusing([a]).leafIDs.count, 3)
    }

    func testEveryKindOfScreenGetsItsOwnShapes() {
        let ids = { (w: CGFloat, h: CGFloat) in LayoutPreset.suggested(for: CGSize(width: w, height: h)).map(\.id) }
        let sets = [ids(3440, 1440), ids(1920, 1080), ids(1200, 1000), ids(1080, 1920)]
        XCTAssertTrue(sets.allSatisfy { $0.count >= 10 }, "no id is missing from the catalog")
        XCTAssertEqual(Set(sets.map { $0.joined(separator: ",") }).count, 4)
        XCTAssertEqual(sets[0].first, "columns3")
        XCTAssertEqual(sets[3].first, "rows2")
    }
}
