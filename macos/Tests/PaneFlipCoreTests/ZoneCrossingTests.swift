import XCTest
import CoreGraphics
import PaneFlipCore

final class ZoneCrossingTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 300, height: 200)
    // Two columns, the right one split in two rows.
    private let left = CGRect(x: 0, y: 0, width: 150, height: 200)
    private let rightTop = CGRect(x: 150, y: 0, width: 150, height: 100)
    private let rightBottom = CGRect(x: 150, y: 100, width: 150, height: 100)

    func testGoingRightEntersTheLeftColumnAtTheSameHeight() {
        let zones = [(id: "left", rect: left), (id: "top", rect: rightTop), (id: "bottom", rect: rightBottom)]
        XCTAssertEqual(ZoneCrossing.entered(going: .right, along: 0.5, among: zones, screen: screen), "left")
    }

    func testGoingLeftEntersTheRightColumnAtTheSameHeight() {
        let zones = [(id: "left", rect: left), (id: "top", rect: rightTop), (id: "bottom", rect: rightBottom)]
        XCTAssertEqual(ZoneCrossing.entered(going: .left, along: 0.2, among: zones, screen: screen), "top")
        XCTAssertEqual(ZoneCrossing.entered(going: .left, along: 0.9, among: zones, screen: screen), "bottom")
    }

    func testGoingDownEntersTheTopAtTheSamePlaceAcross() {
        let zones = [(id: "left", rect: left), (id: "top", rect: rightTop), (id: "bottom", rect: rightBottom)]
        XCTAssertEqual(ZoneCrossing.entered(going: .down, along: 0.2, among: zones, screen: screen), "left")
        XCTAssertEqual(ZoneCrossing.entered(going: .down, along: 0.8, among: zones, screen: screen), "top")
        XCTAssertEqual(ZoneCrossing.entered(going: .up, along: 0.8, among: zones, screen: screen), "bottom")
    }

    func testTheLightKeepsItsPlaceAlongTheEdge() {
        XCTAssertEqual(ZoneCrossing.along(rightBottom, onScreen: true, in: screen, going: .right), 0.75)
        XCTAssertEqual(ZoneCrossing.along(rightBottom, onScreen: true, in: screen, going: .down), 0.75)
        XCTAssertEqual(ZoneCrossing.along(left, onScreen: false, in: screen, going: .right), 0.5, "a zone out of sight has no place: the middle")
        XCTAssertNil(ZoneCrossing.entered(going: .right, along: 0.5, among: [(id: Int, rect: CGRect)](), screen: screen))
    }
}
