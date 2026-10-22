import XCTest
@testable import PaneFlipCore

final class FingerSwipeTests: XCTestCase {
    /// `frames` reports of `count` fingers whose centre goes from `from` to `to` (in the trackpad's width) in even steps.
    private func swipe(_ s: inout FingerSwipe, fingers count: Int, frames: Int, from: Double = 0.5, to: Double = 0.5, y: Double = 0.5) -> [FingerSwipe.Output] {
        (0..<frames).flatMap { i in
            s.add(fingers: count, x: from + (to - from) * Double(i) / Double(max(frames - 1, 1)), y: y, at: Double(i) / 100)
        }
    }

    func testThreeFingersSettleAndThenMovingToTheSideBeginsASwipe() {
        var s = FingerSwipe()
        XCTAssertTrue(swipe(&s, fingers: 3, frames: 3).isEmpty, "still settling")
        let out = swipe(&s, fingers: 3, frames: 6, from: 0.5, to: 0.6)
        XCTAssertEqual(out.first, .began(fingers: 3))
        guard case .moved(let first, _) = out[1] else { return XCTFail("moves follow the beginning") }
        XCTAssertGreaterThan(first, 0, "to the right is positive")
    }

    func testFourFingersLandingThroughThreeDoNotBeginASwipeWithThree() {
        var s = FingerSwipe()
        XCTAssertTrue(swipe(&s, fingers: 3, frames: 3, from: 0.4, to: 0.45).isEmpty, "the fourth finger lands before the movement counts")
        let out = swipe(&s, fingers: 4, frames: 8, from: 0.45, to: 0.7)
        XCTAssertEqual(out.first, .began(fingers: 4))
    }

    func testASwipeThatBeginsUpOrDownMovesNothing() {
        var s = FingerSwipe()
        _ = swipe(&s, fingers: 3, frames: 4)
        var out: [FingerSwipe.Output] = []
        for i in 0..<10 { out += s.add(fingers: 3, x: 0.5, y: 0.5 + Double(i) * 0.02, at: Double(i)) }
        XCTAssertTrue(out.isEmpty)
    }

    func testLiftingTheFingersEndsTheSwipeAndAFingerThatComesOrGoesEndsItForGood() {
        var s = FingerSwipe()
        _ = swipe(&s, fingers: 3, frames: 4)
        _ = swipe(&s, fingers: 3, frames: 6, from: 0.5, to: 0.7)
        XCTAssertEqual(s.add(fingers: 0, x: 0, y: 0, at: 1), [.ended])

        _ = swipe(&s, fingers: 4, frames: 4)
        _ = swipe(&s, fingers: 4, frames: 6, from: 0.5, to: 0.7)
        XCTAssertEqual(s.add(fingers: 3, x: 0.7, y: 0.5, at: 2), [.ended], "one finger came off")
        XCTAssertTrue(swipe(&s, fingers: 3, frames: 12, from: 0.7, to: 0.2).isEmpty, "the three left do not start another")
        XCTAssertTrue(s.add(fingers: 2, x: 0.5, y: 0.5, at: 3).isEmpty)
        _ = swipe(&s, fingers: 3, frames: 4)
        XCTAssertFalse(swipe(&s, fingers: 3, frames: 6, from: 0.5, to: 0.7).isEmpty, "once down to two, a new swipe may begin")
    }
}
