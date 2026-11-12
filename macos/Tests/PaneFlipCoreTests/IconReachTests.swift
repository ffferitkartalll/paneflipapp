import XCTest
@testable import PaneFlipCore

final class IconReachTests: XCTestCase {
    private func contains(_ x: CGFloat, _ y: CGFloat, reach: CGFloat) -> Bool {
        IconReach.contains(CGPoint(x: x, y: y), iconMidX: 1000, iconWidth: 30, displayTop: 900, barHeight: 24, reach: reach)
    }

    func testOnTheIconTheReachIsItsOwnWidthAndTheHeightOfTheMenuBar() {
        XCTAssertTrue(contains(1000, 890, reach: 0))
        XCTAssertTrue(contains(1015, 876, reach: 0), "its corner")
        XCTAssertFalse(contains(1016, 890, reach: 0), "beside it")
        XCTAssertFalse(contains(1000, 875, reach: 0), "below the menu bar")
    }

    func testWhileAWindowIsDraggedTheReachGrowsRoundTheIconAndBelowIt() {
        XCTAssertTrue(contains(1080, 890, reach: 72))
        XCTAssertTrue(contains(1000, 810, reach: 72))
        XCTAssertFalse(contains(1088, 890, reach: 72))
        XCTAssertFalse(contains(1000, 803, reach: 72))
    }
}
