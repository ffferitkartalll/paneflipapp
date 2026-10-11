import XCTest
@testable import PaneFlipCore

final class ZoneRemapperTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1000, height: 400)

    func testCoverageMapsMergedZoneToItsSurvivor() {
        let a = UUID(), b = UUID()
        let old = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b))
        let new = LayoutNode.leaf(a)
        XCTAssertEqual(ZoneRemapper.byCoverage(old: old, new: new, in: area), [b: a])
    }

    func testOrderMapsSurplusOntoLastZone() {
        let o1 = UUID(), o2 = UUID(), o3 = UUID(), n1 = UUID(), n2 = UUID()
        let old = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(o1),
                                   second: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(o2), second: .leaf(o3)))
        let new = LayoutNode.split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(n1), second: .leaf(n2))
        XCTAssertEqual(ZoneRemapper.byOrder(old: old, new: new), [o1: n1, o2: n2, o3: n2])
    }
}
