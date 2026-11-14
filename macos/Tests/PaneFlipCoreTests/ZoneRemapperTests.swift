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

    func testTheZonesOfARemovedScreenBeyondTheEdgeGoToTheHomeZoneAndNoOthers() {
        let screen = UUID(), kept = UUID(), gone = UUID(), home = UUID()
        let old = StripLayout(leading: [Overflow(width: 0.5, root: .leaf(kept))], root: .leaf(screen), trailing: [Overflow(width: 0.5, root: .leaf(gone))])
        let new = StripLayout(leading: old.leading, root: .leaf(UUID()), trailing: [])
        XCTAssertEqual(ZoneRemapper.beyondEdges(old: old, new: new, home: home), [gone: home])
    }
}
