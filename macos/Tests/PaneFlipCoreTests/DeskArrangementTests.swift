import XCTest
import CoreGraphics
import PaneFlipCore

final class DeskArrangementTests: XCTestCase {
    private let a = (id: "a", size: CGSize(width: 1000, height: 600))
    private let b = (id: "b", size: CGSize(width: 1200, height: 700))

    func testNothingIsSetUntilEveryDisplayHasAPlace() {
        var desk = DeskArrangement()
        XCTAssertFalse(desk.isSet(for: [a, b]))
        desk.origins["a"] = .zero
        XCTAssertFalse(desk.isSet(for: [a, b]))
        desk.origins["b"] = CGPoint(x: 1000, y: 0)
        XCTAssertTrue(desk.isSet(for: [a, b]))
    }

    func testDisplaysWithoutAPlaceLieInARowInTheGivenOrder() {
        let frames = DeskArrangement().frames(of: [a, b])
        XCTAssertEqual(frames["a"], CGRect(x: 0, y: 0, width: 1000, height: 600))
        XCTAssertEqual(frames["b"], CGRect(x: 1000, y: 0, width: 1200, height: 700))
    }

    func testAPlacedDisplayKeepsItsPlaceAndANewOneGoesBeyondIt() {
        let desk = DeskArrangement(origins: ["a": CGPoint(x: 50, y: 20)])
        let frames = desk.frames(of: [a, b])
        XCTAssertEqual(frames["a"], CGRect(x: 50, y: 20, width: 1000, height: 600))
        XCTAssertEqual(frames["b"]?.origin, CGPoint(x: 1050, y: 0))
    }

    func testMappingMovesARectangleWithItsDisplay() {
        let screen = CGRect(x: 1000, y: -300, width: 1000, height: 600)
        let desk = CGRect(x: 0, y: 40, width: 1000, height: 600)
        XCTAssertEqual(DeskArrangement.map(CGRect(x: 1100, y: -200, width: 200, height: 100), from: screen, to: desk),
                       CGRect(x: 100, y: 140, width: 200, height: 100))
    }

    func testTheArrangementSurvivesBeingSaved() throws {
        let desk = DeskArrangement(origins: ["a": CGPoint(x: 5, y: 6)])
        XCTAssertEqual(try JSONDecoder().decode(DeskArrangement.self, from: JSONEncoder().encode(desk)), desk)
    }
}
