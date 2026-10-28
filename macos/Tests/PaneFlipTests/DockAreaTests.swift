import XCTest
import CoreGraphics

final class DockAreaTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 1680, height: 1050)
    private var area: CGRect { CGRect(x: 0, y: 30, width: 1680, height: 1020) }   // below the menu bar

    func testADockAtTheBottomTakesItsStrip() {
        let dock = CGRect(x: 200, y: 976, width: 1280, height: 60)
        let usable = DockArea.excluding(dock, from: area, onDisplay: display)
        XCTAssertEqual(usable, CGRect(x: 0, y: 30, width: 1680, height: 946))
    }

    func testADockOnAnotherDisplayChangesNothing() {
        let dock = CGRect(x: 2000, y: 1370, width: 1228, height: 60)
        XCTAssertEqual(DockArea.excluding(dock, from: area, onDisplay: display), area)
    }

    func testRoomTheSystemAlreadyMadeForTheDockIsNotTakenTwice() {
        let dock = CGRect(x: 200, y: 976, width: 1280, height: 60)
        let reserved = CGRect(x: 0, y: 30, width: 1680, height: 950)   // the system left 70 points at the bottom
        XCTAssertEqual(DockArea.excluding(dock, from: reserved, onDisplay: display), reserved)
    }

    func testNoDockChangesNothing() {
        XCTAssertEqual(DockArea.excluding(nil, from: area, onDisplay: display), area)
    }

    func testADockAtTheSideTakesItsStrip() {
        let left = CGRect(x: 0, y: 300, width: 70, height: 600)
        XCTAssertEqual(DockArea.excluding(left, from: area, onDisplay: display),
                       CGRect(x: 70, y: 30, width: 1610, height: 1020))
        let right = CGRect(x: 1610, y: 300, width: 70, height: 600)
        XCTAssertEqual(DockArea.excluding(right, from: area, onDisplay: display),
                       CGRect(x: 0, y: 30, width: 1610, height: 1020))
    }

    func testTheTrayIsWidenedToTheWholeStripOfItsEdge() {
        let tray = CGRect(x: 200, y: 980, width: 1280, height: 60)
        XCTAssertEqual(DockArea.reserved(tray, strip: 70, orientation: nil, onDisplay: display), CGRect(x: 200, y: 980, width: 1280, height: 70))
        XCTAssertEqual(DockArea.reserved(tray, strip: 60, orientation: "bottom", onDisplay: display), CGRect(x: 200, y: 990, width: 1280, height: 60))
        XCTAssertEqual(DockArea.reserved(CGRect(x: 5, y: 300, width: 60, height: 600), strip: 70, orientation: "left", onDisplay: display),
                       CGRect(x: 0, y: 300, width: 70, height: 600))
        XCTAssertEqual(DockArea.reserved(CGRect(x: 1620, y: 300, width: 60, height: 600), strip: 70, orientation: "right", onDisplay: display),
                       CGRect(x: 1610, y: 300, width: 70, height: 600))
    }

    func testAStandInForAMissedDockTakesTheStripOfItsEdge() {
        for orientation in [nil, "left", "right"] {
            let stand = DockArea.reserved(DockArea.standIn(orientation: orientation, onDisplay: display), strip: 70, orientation: orientation, onDisplay: display)
            let usable = DockArea.excluding(stand, from: area, onDisplay: display)
            switch orientation {
            case "left": XCTAssertEqual(usable, CGRect(x: 70, y: 30, width: 1610, height: 1020))
            case "right": XCTAssertEqual(usable, CGRect(x: 0, y: 30, width: 1610, height: 1020))
            default: XCTAssertEqual(usable, CGRect(x: 0, y: 30, width: 1680, height: 950))
            }
        }
    }
}
