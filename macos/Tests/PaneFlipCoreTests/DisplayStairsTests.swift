import XCTest
import CoreGraphics
import PaneFlipCore

final class DisplayStairsTests: XCTestCase {
    private let a = CGRect(x: 0, y: 0, width: 1000, height: 600)

    func testEachDisplayAboveTheOneBeforeIsAStaircase() {
        let b = CGRect(x: 1000, y: 600, width: 1200, height: 700)
        let c = CGRect(x: 2200, y: 1300, width: 800, height: 500)
        let stairs = DisplayStairs([("c", c), ("a", a), ("b", b)])
        XCTAssertEqual(stairs.order, ["a", "b", "c"])
        XCTAssertEqual(stairs.steps, [.up, .up])
        XCTAssertTrue(stairs.isStaircase)
    }

    func testDisplaysSideBySideAreLevel() {
        let stairs = DisplayStairs([("a", a), ("b", CGRect(x: 1000, y: 100, width: 1200, height: 700))])
        XCTAssertEqual(stairs.steps, [.level])
        XCTAssertFalse(stairs.isStaircase)
    }

    func testAStaircaseGoingDownIsNotOne() {
        let stairs = DisplayStairs([("a", a), ("b", CGRect(x: 1000, y: -700, width: 1200, height: 700))])
        XCTAssertEqual(stairs.steps, [.down])
        XCTAssertFalse(stairs.isStaircase)
    }

    func testOneDisplayHasNothingToArrange() {
        XCTAssertTrue(DisplayStairs([("a", a)]).isStaircase)
    }

    func testOneStepWrongSpoilsTheStaircase() {
        let b = CGRect(x: 1000, y: 600, width: 1200, height: 700)
        let c = CGRect(x: 2200, y: 900, width: 800, height: 500)
        XCTAssertEqual(DisplayStairs([("a", a), ("b", b), ("c", c)]).steps, [.up, .level])
    }
}
