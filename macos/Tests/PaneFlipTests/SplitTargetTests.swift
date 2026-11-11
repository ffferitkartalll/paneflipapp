import XCTest
import CoreGraphics
import PaneFlipCore

/// The line a click would make in the layout editor, before the click: it is drawn as the line will be once it is there.
final class SplitTargetTests: XCTestCase {
    func testTheLineOfAZoneAlongTheScreensEdgesReachesThem() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 500), inner = LayoutNode.lineArea(screen.insetBy(dx: 20, dy: 20), gap: 10)
        // The zone at the top, right of a line at the middle: it lies along the top margin, not along the bottom.
        let zone = ZoneRect(id: UUID(), index: 0, rect: CGRect(x: 505, y: 20, width: 475, height: 220))
        let target = SplitTarget(zone: zone, sideBySide: true, ratio: 0.5, valid: true, snapped: false, gap: 10, reach: (inner, screen))
        XCTAssertEqual(target.line.0.y, 0, "on to the screen's edge, past the margin")
        XCTAssertEqual(target.line.1.y, 245, "to the middle of the gap under the zone, as its line will")
        XCTAssertEqual(target.line.0.x, 742.5)
    }

    func testTheLineOfAZoneBeyondTheEdgeStaysInItsZone() {
        let zone = ZoneRect(id: UUID(), index: 0, rect: CGRect(x: 0, y: 0, width: 400, height: 300))
        let target = SplitTarget(zone: zone, sideBySide: false, ratio: 0.5, valid: true, snapped: false)
        XCTAssertEqual(target.line.0, CGPoint(x: 0, y: 150))
        XCTAssertEqual(target.line.1, CGPoint(x: 400, y: 150))
    }
}
