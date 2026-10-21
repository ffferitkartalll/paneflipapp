import XCTest
@testable import PaneFlipCore

final class PagedScrollTests: XCTestCase {
    func testASwipeMovesAScreenOnceItHasGoneFarEnoughAndNeverTwice() {
        var scroll = PagedScroll()
        XCTAssertEqual(scroll.add(horizontal: -20, finished: false), 0)
        XCTAssertEqual(scroll.add(horizontal: -30, finished: false), 0)
        XCTAssertEqual(scroll.add(horizontal: -20, finished: false), 1, "the content went to the left: the screen on the right")
        XCTAssertEqual(scroll.add(horizontal: -400, finished: false), 0, "one screen for each swipe")
        XCTAssertEqual(scroll.add(horizontal: 0, finished: true), 0)

        XCTAssertEqual(scroll.add(horizontal: 70, finished: false), -1, "the next swipe starts afresh")
    }

    func testASwipeThatTurnsBackCountsFromWhereItIs() {
        var scroll = PagedScroll()
        XCTAssertEqual(scroll.add(horizontal: -50, finished: false), 0)
        XCTAssertEqual(scroll.add(horizontal: 40, finished: false), 0, "it is back near the start")
        XCTAssertEqual(scroll.add(horizontal: 80, finished: false), -1)
    }

    func testAShortSwipeMovesNothingAndIsForgotten() {
        var scroll = PagedScroll()
        XCTAssertEqual(scroll.add(horizontal: -30, finished: false), 0)
        XCTAssertEqual(scroll.add(horizontal: 0, finished: true), 0)
        XCTAssertEqual(scroll.add(horizontal: -40, finished: false), 0, "the 30 points of the earlier swipe are not kept")
    }

    func testEachNotchOfAWheelIsAStep() {
        XCTAssertEqual(PagedScroll.notch(-1), 1, "toward you: the screen on the right")
        XCTAssertEqual(PagedScroll.notch(3), -1, "away from you: the one on the left")
        XCTAssertEqual(PagedScroll.notch(0), 0)
    }
}
