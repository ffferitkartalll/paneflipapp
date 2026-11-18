import XCTest
@testable import PaneFlipCore

final class PagedScrollOffsetTests: XCTestCase {
    func testStepsFromEdgeToEdge() {
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 0, pitch: 100, maxOffset: 450), 100)
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 100, pitch: 100, maxOffset: 450), 200)
        XCTAssertEqual(PagedScroll.offset(after: -1, from: 200, pitch: 100, maxOffset: 450), 100)
    }

    func testStopsAtTheEnds() {
        XCTAssertEqual(PagedScroll.offset(after: -1, from: 0, pitch: 100, maxOffset: 450), 0)
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 400, pitch: 100, maxOffset: 450), 450)
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 450, pitch: 100, maxOffset: 450), 450)
    }

    func testFromBetweenEdges() {
        XCTAssertEqual(PagedScroll.offset(after: -1, from: 450, pitch: 100, maxOffset: 450), 400)
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 130, pitch: 100, maxOffset: 450), 200)
        XCTAssertEqual(PagedScroll.offset(after: -1, from: 130, pitch: 100, maxOffset: 450), 100)
    }

    func testNothingToScrollInARowThatFits() {
        XCTAssertEqual(PagedScroll.offset(after: 1, from: 0, pitch: 100, maxOffset: 0), 0)
    }
}
