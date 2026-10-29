import XCTest
import CoreGraphics
import PaneFlipCore

final class DeskPointerTests: XCTestCase {
    // The system arranges them as a staircase (B above and to the right of A); on the desk B lies right beside A, level with its top.
    private let a = DeskPointer.Display(id: "a", frame: CGRect(x: 0, y: 0, width: 1000, height: 600), desk: CGRect(x: 0, y: 0, width: 1000, height: 600))
    private let b = DeskPointer.Display(id: "b", frame: CGRect(x: 1000, y: -800, width: 2000, height: 800), desk: CGRect(x: 1000, y: 0, width: 2000, height: 800))
    private var pointer: DeskPointer { DeskPointer(displays: [a, b]) }

    func testPushedAgainstTheRightEdgeItComesInAtTheSameHeightOnTheDeskOnTheNextDisplay() {
        let target = pointer.target(from: CGPoint(x: 999.5, y: 300), delta: CGVector(dx: 5, dy: 0))
        XCTAssertEqual(target, CGPoint(x: 1001, y: -800 + 300))
    }

    func testPushedBackAgainstTheLeftEdgeItGoesBack() {
        let target = pointer.target(from: CGPoint(x: 1000.5, y: -500), delta: CGVector(dx: -5, dy: 0))
        XCTAssertEqual(target, CGPoint(x: 998, y: 300))
    }

    func testNothingHappensAwayFromTheEdgeOrWhenMovingInward() {
        XCTAssertNil(pointer.target(from: CGPoint(x: 500, y: 300), delta: CGVector(dx: 5, dy: 0)))
        XCTAssertNil(pointer.target(from: CGPoint(x: 999.5, y: 300), delta: CGVector(dx: -5, dy: 0)))
    }

    func testNothingHappensWhereNoDisplayLiesBesideItOnTheDesk() {
        XCTAssertNil(pointer.target(from: CGPoint(x: 999.5, y: 700), delta: CGVector(dx: 5, dy: 0)), "below the end of B on the desk")
        XCTAssertNil(pointer.target(from: CGPoint(x: 10, y: 300), delta: CGVector(dx: -5, dy: 0)), "nothing to the left of A")
    }

    func testDisplaysStackedOnTheDeskAreCrossedUpAndDown() {
        let top = DeskPointer.Display(id: "top", frame: CGRect(x: 0, y: -600, width: 1000, height: 600), desk: CGRect(x: 0, y: 0, width: 1000, height: 600))
        let bottom = DeskPointer.Display(id: "bottom", frame: CGRect(x: 2000, y: 0, width: 1000, height: 600), desk: CGRect(x: 0, y: 600, width: 1000, height: 600))
        let stacked = DeskPointer(displays: [top, bottom])
        XCTAssertEqual(stacked.target(from: CGPoint(x: 400, y: -0.5), delta: CGVector(dx: 0, dy: 4)), CGPoint(x: 2400, y: 1))
        XCTAssertEqual(stacked.target(from: CGPoint(x: 2400, y: 0.5), delta: CGVector(dx: 0, dy: -4)), CGPoint(x: 400, y: -2))
        XCTAssertNil(stacked.target(from: CGPoint(x: 400, y: -599.5), delta: CGVector(dx: 0, dy: -4)), "nothing above the top one")
    }
}
