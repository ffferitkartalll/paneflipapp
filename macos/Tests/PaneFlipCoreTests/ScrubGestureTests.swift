import XCTest
@testable import PaneFlipCore

final class ScrubGestureTests: XCTestCase {
    private func swipe(_ steps: [(delta: CGFloat, at: TimeInterval)]) -> ScrubGesture {
        var gesture = ScrubGesture()
        for step in steps { gesture.add(step.delta, at: step.at) }
        return gesture
    }

    func testASlowShortSwipeLetsTheWindowStay() {
        let gesture = swipe([(-20, 0), (-20, 0.3), (-20, 0.6)])   // 60 pt of 400, slowly
        XCTAssertEqual(gesture.shift(zoneWidth: 400, current: 1, count: 3), 0)
    }

    func testAWideSwipeMovesOnOneWindowForEachWidthOfTheZone() {
        let toTheLeft = swipe([(-60, 0), (-60, 0.4), (-20, 0.8)])   // 140 pt of 400: more than 30 %
        XCTAssertEqual(toTheLeft.shift(zoneWidth: 400, current: 1, count: 4), 1, "content taken to the left shows the next window")
        let toTheRight = swipe([(60, 0), (60, 0.4), (20, 0.8)])
        XCTAssertEqual(toTheRight.shift(zoneWidth: 400, current: 1, count: 4), -1)

        let far = swipe([(-300, 0), (-300, 0.6), (-300, 1.2)])   // 900 pt of 400: two widths and a bit
        XCTAssertEqual(far.shift(zoneWidth: 400, current: 0, count: 6), 2, "past the first neighbour, as far as the fingers went")
    }

    func testAFlickGoesAtLeastOneWindowAndFurtherWhenItIsFast() {
        let short = swipe([(-12, 0), (-14, 0.03), (-16, 0.06)])   // 42 pt in 60 ms
        XCTAssertEqual(short.shift(zoneWidth: 800, current: 1, count: 4), 1)
        let hard = swipe([(-150, 0), (-200, 0.05), (-250, 0.1)])   // 600 pt in 100 ms, 6000 pt/s
        XCTAssertGreaterThan(abs(hard.shift(zoneWidth: 400, current: 0, count: 10)), 1, "it carries on over several windows")
    }

    func testTheEndsAreNotPassed() {
        let far = swipe([(-300, 0), (-300, 0.6), (-300, 1.2)])
        XCTAssertEqual(far.shift(zoneWidth: 400, current: 1, count: 3), 1, "only one window is left that way")
        XCTAssertEqual(far.shift(zoneWidth: 400, current: 2, count: 3), 0)
    }

    func testAFlickBackAfterAWideSwipeCancels() {
        let swipeAndBack = swipe([(-200, 0), (-50, 0.1), (60, 0.2), (80, 0.25)])   // taken far left, flicked back right
        XCTAssertEqual(swipeAndBack.shift(zoneWidth: 400, current: 1, count: 3), 0)
    }

    func testWhereTheContentLandsIsWhereItIsOrFurtherAfterAFlick() {
        let slow = swipe([(-60, 0), (-60, 0.5)])
        XCTAssertEqual(slow.landing, -120)
        let flick = swipe([(-100, 0), (-100, 0.05), (-100, 0.1)])   // 3000 pt/s
        XCTAssertLessThan(flick.landing, -300, "it goes on a little further than the fingers did")
    }
}
