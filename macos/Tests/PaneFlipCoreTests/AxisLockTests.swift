import XCTest
@testable import PaneFlipCore

final class AxisLockTests: XCTestCase {
    func testNothingFollowsUntilTheFingersHaveGoneFarEnoughToTellTheDirection() {
        var lock = AxisLock()
        XCTAssertEqual(lock.add(horizontal: 3, vertical: 0), 0)
        XCTAssertEqual(lock.add(horizontal: 3, vertical: 1), 0)
        XCTAssertEqual(lock.decision, .undecided)
    }

    func testASwipeToTheSideFollowsFromWhereItBeganAndThenEveryMove() {
        var lock = AxisLock()
        _ = lock.add(horizontal: -4, vertical: 1)
        XCTAssertEqual(lock.add(horizontal: -6, vertical: 1), -10, "what the fingers did while it was being decided is not lost")
        XCTAssertEqual(lock.decision, .horizontal)
        XCTAssertEqual(lock.add(horizontal: -5, vertical: 40), -5, "up and down mean nothing once it is horizontal")
    }

    func testASwipeUpOrDownNeverMovesAnythingNotEvenWhenItTurnsToTheSide() {
        var lock = AxisLock()
        XCTAssertEqual(lock.add(horizontal: 1, vertical: 12), 0)
        XCTAssertEqual(lock.decision, .vertical)
        XCTAssertEqual(lock.add(horizontal: 300, vertical: 0), 0)
        XCTAssertEqual(lock.add(horizontal: -200, vertical: 5), 0)
    }

    func testAnUndecidedDiagonalCountsAsVerticalAndALittleSlantAsHorizontal() {
        var diagonal = AxisLock()
        XCTAssertEqual(diagonal.add(horizontal: 9, vertical: 9), 0)
        XCTAssertEqual(diagonal.decision, .vertical, "unclear: leave the windows alone")

        var slanted = AxisLock()   // about 20 degrees off the level
        XCTAssertEqual(slanted.add(horizontal: 19, vertical: 7), 19)
        XCTAssertEqual(slanted.decision, .horizontal)
    }

    func testEachSwipeStartsAgainWithANewLock() {
        var lock = AxisLock()
        _ = lock.add(horizontal: 0, vertical: 20)
        XCTAssertEqual(lock.decision, .vertical)
        lock = AxisLock()
        XCTAssertEqual(lock.add(horizontal: 20, vertical: 0), 20)
    }
}
