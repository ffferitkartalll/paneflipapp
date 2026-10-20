import PaneFlipCore
import XCTest

final class PillMetricsTests: XCTestCase {
    func testThePillAsAWholeIsCentredOnTheZoneBelowTheMenuBarHeight() {
        let zone = CGRect(x: 100, y: 50, width: 800, height: 600)
        let frame = PillMetrics.panelFrame(inZone: zone, width: 400, menuBarThickness: 24)
        XCTAssertEqual(frame.midX, zone.midX, "the same room on the left and on the right")
        XCTAssertEqual(frame, CGRect(x: 300, y: 74, width: 400, height: PillMetrics.height))
    }

    func testThePillCanSitAlongTheBottomOfTheZone() {
        let zone = CGRect(x: 100, y: 50, width: 800, height: 600)
        let frame = PillMetrics.panelFrame(inZone: zone, width: 400, menuBarThickness: 24, position: .bottom)
        XCTAssertEqual(frame, CGRect(x: 300, y: 650 - 24 - PillMetrics.height, width: 400, height: PillMetrics.height))
    }

    func testAZoneNarrowerThanThePillStillGetsItCentred() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 300)
        XCTAssertEqual(PillMetrics.panelFrame(inZone: zone, width: 400, menuBarThickness: 24).midX, 100)
    }
}
