import XCTest
@testable import PaneFlipCore

final class ParkingTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 5120, height: 1440)

    func testAParkedWindowKeepsOnePixelOnTheDisplay() {
        let zone = CGRect(x: 6000, y: 66, width: 1280, height: 1344)
        XCTAssertEqual(Parking.frame(for: zone, on: display, side: .right), CGRect(x: 5119, y: 66, width: 1280, height: 1344))
        XCTAssertEqual(Parking.frame(for: zone, on: display, side: .left), CGRect(x: -1279, y: 66, width: 1280, height: 1344))
    }

    func testAWindowWaitsAtTheCornerOfTheHiddenDisplayWithItsSize() {
        let hidden = CGRect(x: 5120, y: 1440, width: 5120, height: 1440)
        let zone = CGRect(x: 6000, y: 66, width: 1280, height: 1344)
        XCTAssertEqual(Parking.frame(for: zone, on: display, place: .display(hidden)), CGRect(x: 5120, y: 1440, width: 1280, height: 1344))
    }

    func testEachDisplayHasItsHiddenDisplayAtItsLowerRightCornerAsLargeAsIt() {
        let below = CGRect(x: -1680, y: 1440, width: 1680, height: 1050)   // the staircase: the main display is above it and to its right
        XCTAssertEqual(Parking.hiddenArea(for: display, avoiding: [below]), CGRect(x: 5120, y: 1440, width: 5120, height: 1440))
        XCTAssertEqual(Parking.hiddenArea(for: below, avoiding: [display]), CGRect(x: 0, y: 2490, width: 1680, height: 1050))
    }

    func testAHiddenDisplayThatWouldLieOnAnotherDisplayOrHiddenDisplayIsNotMade() {
        let right = CGRect(x: 5120, y: 600, width: 1920, height: 1080)   // lies where the hidden display of `display` would be
        XCTAssertNil(Parking.hiddenArea(for: display, avoiding: [right]))
        let hiddenOfOther = CGRect(x: 6000, y: 1500, width: 100, height: 100)
        XCTAssertNil(Parking.hiddenArea(for: display, avoiding: [hiddenOfOther]))
    }

    func testAWindowThatWaitsForAMomentGoesToTheLowerCornerOfTheEdgeOrTheCornerOfTheHiddenDisplay() {
        let zone = CGRect(x: 6000, y: 66, width: 1280, height: 1344)
        XCTAssertEqual(Parking.transitOrigin(for: zone, on: display, place: .edge(.right)), CGPoint(x: 5119, y: 1439))
        XCTAssertEqual(Parking.transitOrigin(for: zone, on: display, place: .edge(.left)), CGPoint(x: -1279, y: 1439))
        XCTAssertEqual(Parking.transitOrigin(for: zone, on: display, place: .display(CGRect(x: 5120, y: 1440, width: 5120, height: 1440))), CGPoint(x: 5120, y: 1440))
    }
}
