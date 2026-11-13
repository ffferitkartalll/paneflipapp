import XCTest
@testable import PaneFlipCore

final class ZoneGridTests: XCTestCase {
    func testTheGridHasTwoByTwoThreeByThreeFourByFourAndSoOnAsTheWindowsMultiply() {
        for count in [0, 1, 2, 3, 4] { XCTAssertEqual(ZoneGrid.side(forCards: count), 2, "\(count)") }
        for count in [5, 6, 9] { XCTAssertEqual(ZoneGrid.side(forCards: count), 3, "\(count)") }
        for count in [10, 12, 16] { XCTAssertEqual(ZoneGrid.side(forCards: count), 4, "\(count)") }
        XCTAssertEqual(ZoneGrid.side(forCards: 17), 5)
    }

    func testACardIsAsLargeWithOneWindowMoreOrLessAsLongAsTheGridStaysTheSame() {
        let size = CGSize(width: 800, height: 600)
        let two = ZoneGrid.cells(count: 2, in: size, gap: 10), four = ZoneGrid.cells(count: 4, in: size, gap: 10)
        XCTAssertEqual(two[0].size, four[0].size)
        XCTAssertEqual(four[0], CGRect(x: 0, y: 0, width: 395, height: 295))
        XCTAssertEqual(four[3], CGRect(x: 405, y: 305, width: 395, height: 295))
        XCTAssertNotEqual(ZoneGrid.cells(count: 5, in: size, gap: 10)[0].size, four[0].size, "the fifth window makes it three by three")
    }

    func testThereIsExactlyTheGapBetweenTheCardsAlongTheRowsAndBetweenThem() {
        for size in [CGSize(width: 800, height: 600), CGSize(width: 500, height: 900), CGSize(width: 1280, height: 400)] {
            for count in [4, 9, 16] {
                let cells = ZoneGrid.cells(count: count, in: size, gap: 14), side = ZoneGrid.side(forCards: count)
                for i in cells.indices {
                    if i % side + 1 < side { XCTAssertEqual(cells[i + 1].minX - cells[i].maxX, 14, accuracy: 0.0001) }
                    if i + side < cells.count { XCTAssertEqual(cells[i + side].minY - cells[i].maxY, 14, accuracy: 0.0001) }
                }
            }
        }
    }

    func testThereIsNoRoomBetweenTheGridAndTheEdgesOfTheZone() {
        let size = CGSize(width: 800, height: 600)
        for count in [4, 9, 16] {
            let cells = ZoneGrid.cells(count: count, in: size, gap: 12)
            XCTAssertEqual(cells.map(\.minX).min(), 0, "\(count)")
            XCTAssertEqual(cells.map(\.minY).min(), 0)
            XCTAssertEqual(cells.map(\.maxX).max()!, 800, accuracy: 0.001)
            XCTAssertEqual(cells.map(\.maxY).max()!, 600, accuracy: 0.001)
        }
        let one = ZoneGrid.cells(count: 1, in: size, gap: 12)
        XCTAssertEqual(one[0].origin, .zero, "a grid that is not full begins at the top left")
        XCTAssertEqual(ZoneGrid.cells(count: 5, in: size, gap: 12)[3].minX, 0, "the second row begins under the first")
    }

    func testAnArrowKeyMovesOneStepAlongTheGridAndNotPastItsEdge() {
        // Five cards, three by three:   0 1 2
        //                               3 4
        func go(_ from: Int, _ columns: Int, _ rows: Int) -> Int { ZoneGrid.moved(from: from, columns: columns, rows: rows, count: 5) }
        XCTAssertEqual(go(0, 1, 0), 1)
        XCTAssertEqual(go(1, 0, 1), 4)
        XCTAssertEqual(go(4, -1, 0), 3)
        XCTAssertEqual(go(3, 0, -1), 0)
        XCTAssertEqual(go(0, -1, 0), 0, "not past the left edge")
        XCTAssertEqual(go(0, 0, -1), 0, "nor the top one")
        XCTAssertEqual(go(2, 1, 0), 2, "nor the right one")
        XCTAssertEqual(go(4, 0, 1), 4, "nor the bottom one")
        XCTAssertEqual(go(4, 1, 0), 4, "the last row is not full: nothing to the right of the fifth card")
        XCTAssertEqual(go(2, 0, 1), 4, "down from the third card, where the second row has none: its last card")
        XCTAssertEqual(ZoneGrid.moved(from: 0, columns: 1, rows: 0, count: 1), 0)
        XCTAssertEqual(ZoneGrid.moved(from: 0, columns: 1, rows: 1, count: 0), 0)
    }

    func testACardCarriedOverTheGridIsPutDownInTheNearestCell() {
        let cells = ZoneGrid.cells(count: 4, in: CGSize(width: 800, height: 600), gap: 10)
        XCTAssertEqual(ZoneGrid.index(at: CGPoint(x: 100, y: 100), in: cells), 0)
        XCTAssertEqual(ZoneGrid.index(at: CGPoint(x: 397, y: 298), in: cells), 0, "in a gap: the nearest, the first at a tie")
        XCTAssertEqual(ZoneGrid.index(at: CGPoint(x: 790, y: 590), in: cells), 3)
        XCTAssertEqual(ZoneGrid.index(at: CGPoint(x: 2000, y: 10), in: cells), 1, "outside: the nearest")
        XCTAssertNil(ZoneGrid.index(at: .zero, in: []))
    }
}
