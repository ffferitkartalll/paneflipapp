import XCTest
@testable import PaneFlipCore

final class ZoneNeighbourTests: XCTestCase {
    /// Left half; the right half split into top and bottom.
    private let zones: [(id: String, rect: CGRect, number: Int)] = [
        ("left", CGRect(x: 0, y: 0, width: 500, height: 800), 3),
        ("topRight", CGRect(x: 504, y: 0, width: 496, height: 400), 4),
        ("bottomRight", CGRect(x: 504, y: 404, width: 496, height: 396), 5),
    ]

    private func go(_ from: String, _ direction: ZoneDirection) -> String? {
        let rect = zones.first { $0.id == from }!.rect
        return ZoneNeighbour.nearest(to: rect, number: zones.first { $0.id == from }!.number, among: zones, toward: direction)
    }

    func testTheZoneBesideIsTheOneInThatDirection() {
        XCTAssertEqual(go("topRight", .left), "left")
        XCTAssertEqual(go("topRight", .down), "bottomRight")
        XCTAssertEqual(go("bottomRight", .up), "topRight")
        XCTAssertEqual(go("left", .right), "topRight", "the first of those that share its side, nearest to its middle")
    }

    func testNothingLiesBeyondTheEdgeOfTheScreen() {
        XCTAssertNil(go("left", .left))
        XCTAssertNil(go("left", .up))
        XCTAssertNil(go("topRight", .up))
        XCTAssertNil(go("bottomRight", .right))
    }

    func testAZoneThatOnlyTouchesAtACornerIsTheFallback() {
        let corner: [(id: String, rect: CGRect, number: Int)] = [("a", CGRect(x: 0, y: 0, width: 100, height: 100), 1), ("b", CGRect(x: 110, y: 200, width: 100, height: 100), 2)]
        XCTAssertEqual(ZoneNeighbour.nearest(to: corner[0].rect, number: 1, among: corner, toward: .right), "b")
    }

    func testOfTwoZonesEquallyNearTheNumberThatFollowsWinsWhateverTheMiddles() {
        // Zone 3 is the tall left zone; zone 5 is the top right one and zone 4 the bottom right one, so the numbers run against the order on the screen.
        let swapped: [(id: String, rect: CGRect, number: Int)] = [
            ("three", CGRect(x: 0, y: 0, width: 500, height: 800), 3),
            ("five", CGRect(x: 504, y: 0, width: 496, height: 400), 5),
            ("four", CGRect(x: 504, y: 404, width: 496, height: 396), 4),
        ]
        XCTAssertEqual(ZoneNeighbour.nearest(to: swapped[0].rect, number: 3, among: swapped, toward: .right), "four")
    }

    func testTheNumberThatFollowsTheOwnNumberWinsNotTheLowestOne() {
        // The tall zone 3 on the right; zones 1 and 2 stacked on its left: from 3 the next one down in the order is 2, not 1.
        let layout: [(id: String, rect: CGRect, number: Int)] = [
            ("one", CGRect(x: 0, y: 0, width: 500, height: 400), 1),
            ("two", CGRect(x: 0, y: 404, width: 500, height: 396), 2),
            ("three", CGRect(x: 504, y: 0, width: 496, height: 800), 3),
        ]
        XCTAssertEqual(ZoneNeighbour.nearest(to: layout[2].rect, number: 3, among: layout, toward: .left), "two")
        XCTAssertEqual(ZoneNeighbour.nearest(to: layout[0].rect, number: 1, among: layout, toward: .right), "three")
    }
}
