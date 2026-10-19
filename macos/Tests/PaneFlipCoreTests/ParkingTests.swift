import XCTest
@testable import PaneFlipCore

final class ParkingTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 5120, height: 1440)

    func testWithNoDisplayBesideItWindowsParkOnTheRight() {
        let above = CGRect(x: 1713, y: -1050, width: 1680, height: 1050)   // touches only the top edge
        XCTAssertEqual(Parking.side(of: display, others: []), .right)
        XCTAssertEqual(Parking.side(of: display, others: [above]), .right)
    }

    func testADisplayOnTheRightSendsWindowsToTheLeft() {
        let right = CGRect(x: 5120, y: 200, width: 1920, height: 1080)
        XCTAssertEqual(Parking.side(of: display, others: [right]), .left)
    }

    func testDisplaysOnBothSidesMeanNoParking() {
        let right = CGRect(x: 5120, y: 0, width: 1920, height: 1080)
        let left = CGRect(x: -1920, y: 300, width: 1920, height: 1080)
        XCTAssertNil(Parking.side(of: display, others: [left, right]))
    }

    func testAParkedWindowKeepsOnePixelOnTheDisplay() {
        let zone = CGRect(x: 6000, y: 66, width: 1280, height: 1344)
        XCTAssertEqual(Parking.frame(for: zone, on: display, side: .right), CGRect(x: 5119, y: 66, width: 1280, height: 1344))
        XCTAssertEqual(Parking.frame(for: zone, on: display, side: .left), CGRect(x: -1279, y: 66, width: 1280, height: 1344))
    }

    func testAWindowFollowsItsZoneUntilOnlyAPixelIsLeftOnTheDisplay() {
        let zone = CGRect(x: 300, y: 0, width: 400, height: 100)
        XCTAssertEqual(Parking.standing(zone, on: display).minX, 300)
        XCTAssertEqual(Parking.standing(zone.offsetBy(dx: 5000, dy: 0), on: display).minX, 5119)
        XCTAssertEqual(Parking.standing(zone.offsetBy(dx: -900, dy: 0), on: display).minX, -399)
        XCTAssertEqual(Parking.standing(zone, on: display).size, zone.size)
    }
}
