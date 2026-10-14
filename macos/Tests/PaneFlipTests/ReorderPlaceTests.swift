import XCTest
import CoreGraphics

final class ReorderPlaceTests: XCTestCase {
    private let rows: [CGFloat] = [44, 44, 44, 44]

    func testTheFirstRowReachesTheEnd() {
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 0, travel: 500), 3)
    }

    func testTheLastRowReachesTheStart() {
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 3, travel: -500), 0)
    }

    func testAMiddleRowReachesBothEnds() {
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 1, travel: 500), 3)
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 2, travel: -500), 0)
    }

    func testARowStaysUntilItHasPassedTheMiddleOfItsNeighbour() {
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 1, travel: 0), 1)
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 1, travel: 20), 1)
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 1, travel: 23), 2)
        XCTAssertEqual(ReorderPlace.target(heights: rows, from: 1, travel: -23), 0)
    }

    func testRowsOfDifferentHeights() {
        // An opened app (200) followed by a closed one (44): dragging the closed one up past the middle moves it first.
        XCTAssertEqual(ReorderPlace.target(heights: [200, 44], from: 1, travel: -101), 0)
        XCTAssertEqual(ReorderPlace.target(heights: [200, 44], from: 1, travel: -90), 1)
    }
}
