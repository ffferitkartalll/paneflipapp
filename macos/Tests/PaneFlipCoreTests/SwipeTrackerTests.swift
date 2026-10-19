import XCTest
@testable import PaneFlipCore

final class SwipeTrackerTests: XCTestCase {
    private var tracker = SwipeTracker()

    private func frames(_ list: [(Int, Double, Double)]) -> [SwipeTracker.Event] {
        list.flatMap { tracker.frame(fingerCount: $0.0, x: $0.1, time: $0.2) }
    }

    func testThreeFingersMovingSidewaysBeginMoveAndEnd() {
        let events = frames([(3, 0.5, 0.00), (3, 0.5, 0.01), (3, 0.6, 0.10), (3, 0.7, 0.20), (0, 0, 0.21)])
        XCTAssertEqual(events.first, .began)
        XCTAssertEqual(events[1], .moved(0))
        XCTAssertEqual(events[3].rounded(), .moved(0.2), "right is positive")
        guard case .ended(let velocity) = events.last else { return XCTFail("no end") }
        XCTAssertEqual(velocity, 1, accuracy: 0.01, "0.1 trackpad widths in 0.1 s")
    }

    func testFingersLiftingOneByOneAtTheEndStayPartOfTheSameSwipe() {
        let events = frames([(3, 0.5, 0), (3, 0.6, 0.1), (2, 0.7, 0.11), (1, 0.9, 0.12), (0, 0, 0.13)])
        XCTAssertEqual(events.filter { if case .ended = $0 { return true } else { return false } }.count, 1)
        XCTAssertEqual(events.filter { $0 == .began }.count, 1)
        XCTAssertFalse(events.contains(.moved(0.4)), "the centre jumping while fingers lift is not movement")
    }

    func testAFingerThatComesBackKeepsTheDistanceContinuous() {
        let events = frames([(3, 0.5, 0), (3, 0.6, 0.05), (2, 0.8, 0.06), (3, 0.9, 0.08)])
        guard case .moved(let d) = events.last else { return XCTFail("no move") }
        XCTAssertEqual(d, 0.1, accuracy: 0.0001, "no jump when the third finger returns")
    }

    func testFingersLandingOneAfterTheOtherBeginTheSwipeWhenThereAreThree() {
        XCTAssertEqual(frames([(1, 0.5, 0), (2, 0.5, 0.02), (3, 0.5, 0.04)]), [.began])
    }

    func testFourFingersAreNotThisSwipeUntilTheyAreAllUp() {
        XCTAssertEqual(frames([(4, 0.5, 0), (3, 0.5, 0.1), (3, 0.6, 0.2)]), [], "a thumb on the pad rules the swipe out")
        XCTAssertEqual(frames([(0, 0, 0.3), (3, 0.5, 0.4)]), [.began])
    }

    func testTheEndNeedsTheFingersUpOrAPause() {
        _ = frames([(3, 0.5, 0), (3, 0.6, 0.1)])
        XCTAssertEqual(tracker.frame(fingerCount: 2, x: 0.6, time: 0.15), [], "within the grace")
        guard case .ended = tracker.frame(fingerCount: 2, x: 0.6, time: 0.35).first else { return XCTFail("a pause ends it") }
    }
}

private extension SwipeTracker.Event {
    func rounded() -> SwipeTracker.Event {
        if case .moved(let d) = self { return .moved((d * 1000).rounded() / 1000) }
        return self
    }
}
