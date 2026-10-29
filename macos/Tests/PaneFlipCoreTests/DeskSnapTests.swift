import XCTest
import CoreGraphics
import PaneFlipCore

final class DeskSnapTests: XCTestCase {
    private let wide = CGRect(x: 0, y: 0, width: 2000, height: 800)

    func testALaptopNearTheMiddleUnderAWideDisplayIsCentredAndFlush() {
        let laptop = CGRect(x: 480, y: 830, width: 1000, height: 600)
        XCTAssertEqual(DeskSnap.origin(of: laptop, among: [wide], threshold: 40), CGPoint(x: 500, y: 800))
    }

    func testADisplayDroppedFarAwayStillComesToRestAgainstAnother() {
        let far = CGRect(x: 5000, y: 3000, width: 1000, height: 600)
        let placed = CGRect(origin: DeskSnap.origin(of: far, among: [wide], threshold: 40), size: far.size)
        XCTAssertFalse(placed.insetBy(dx: 0.5, dy: 0.5).intersects(wide))
        XCTAssertTrue(placed.minX == wide.maxX || placed.minY == wide.maxY)
    }

    func testADisplayDroppedOverAnotherIsPushedOut() {
        let over = CGRect(x: 400, y: 300, width: 1000, height: 600)
        let placed = CGRect(origin: DeskSnap.origin(of: over, among: [wide], threshold: 40), size: over.size)
        XCTAssertFalse(placed.insetBy(dx: 0.5, dy: 0.5).intersects(wide))
    }

    func testBesideADisplayItLinesUpWithTheTopOrTheBottomWhenNear() {
        let side = CGRect(x: 2010, y: 25, width: 1000, height: 600)
        XCTAssertEqual(DeskSnap.origin(of: side, among: [wide], threshold: 40), CGPoint(x: 2000, y: 0))
        let low = CGRect(x: 2010, y: 190, width: 1000, height: 600)
        XCTAssertEqual(DeskSnap.origin(of: low, among: [wide], threshold: 40), CGPoint(x: 2000, y: 200))
    }

    func testOutOfReachOfAnyLineItKeepsItsPlaceAlongTheEdge() {
        let side = CGRect(x: 2010, y: 77, width: 1000, height: 600)
        XCTAssertEqual(DeskSnap.origin(of: side, among: [wide], threshold: 10), CGPoint(x: 2000, y: 77))
    }

    func testAloneItStaysWhereItIs() {
        let alone = CGRect(x: 12, y: 34, width: 100, height: 50)
        XCTAssertEqual(DeskSnap.origin(of: alone, among: [], threshold: 40), alone.origin)
    }
}
