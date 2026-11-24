import XCTest
import CoreGraphics

final class WindowDragCheckTests: XCTestCase {
    private let start = CGRect(x: 100, y: 100, width: 400, height: 300)

    func testAWindowThatMovedIsADrag() {
        XCTAssertTrue(WindowDragCheck.isMove(from: start, to: start.offsetBy(dx: 30, dy: 0)))
        XCTAssertTrue(WindowDragCheck.isMove(from: start, to: start.offsetBy(dx: 3, dy: 3.5)), "diagonal: more than 4 points together")
    }

    func testAWindowThatStayedIsNotADrag() {
        XCTAssertFalse(WindowDragCheck.isMove(from: start, to: start), "a click or a text selection inside it")
        XCTAssertFalse(WindowDragCheck.isMove(from: start, to: start.offsetBy(dx: 4, dy: 0)), "4 points is still not a move")
    }

    func testAResizeIsNotADrag() {
        let grown = CGRect(x: 100, y: 100, width: 450, height: 300)
        XCTAssertFalse(WindowDragCheck.isMove(from: start, to: grown))
        XCTAssertFalse(WindowDragCheck.isMove(from: start, to: CGRect(x: 60, y: 100, width: 440, height: 300)), "dragged by its left edge: the corner moves, the size changes")
        XCTAssertTrue(WindowDragCheck.isMove(from: start, to: CGRect(x: 130, y: 100, width: 401, height: 300)), "a rounding of 1 point in the size is still a move")
    }
}
