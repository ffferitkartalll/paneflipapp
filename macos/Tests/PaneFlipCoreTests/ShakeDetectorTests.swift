import XCTest
@testable import PaneFlipCore

final class ShakeDetectorTests: XCTestCase {
    /// The pointer goes through `points` (x), one every `step` seconds.
    private func shaken(_ points: [CGFloat], step: TimeInterval = 0.05, detector: ShakeDetector = ShakeDetector()) -> Bool {
        var d = detector
        var time = 0.0
        for x in points {
            time += step
            if d.feed(x: x, at: time) { return true }
        }
        return false
    }

    func testAFewQuickSwingsBackAndForthAreAShake() {
        XCTAssertTrue(shaken([0, 80, 0, 80, 0, 80, 0]))
    }

    func testOneSwingBackAndForthIsNot() {
        XCTAssertFalse(shaken([0, 80, 0, 80]))
    }

    func testSmallJitterIsNot() {
        XCTAssertFalse(shaken([0, 20, 0, 20, 0, 20, 0, 20, 0, 20]))
    }

    func testSlowSwingsAreNot() {
        XCTAssertFalse(shaken([0, 80, 0, 80, 0, 80, 0], step: 0.4))
    }

    func testAnOrdinaryDragInOneDirectionIsNot() {
        XCTAssertFalse(shaken(Array(stride(from: 0, through: 1000, by: 10).map { CGFloat($0) })))
    }

    func testItStartsAfreshAfterAShake() {
        var d = ShakeDetector()
        var time = 0.0
        var shakes = 0
        for x in [0, 80, 0, 80, 0, 80, 0, 80, 0, 80, 0, 80, 0, 80, 0] as [CGFloat] {
            time += 0.05
            if d.feed(x: x, at: time) { shakes += 1 }
        }
        XCTAssertEqual(shakes, 2, "fourteen swings: two shakes")
    }
}
