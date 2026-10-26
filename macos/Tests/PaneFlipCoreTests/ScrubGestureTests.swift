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

    func testTheOffsetStaysBetweenTheFirstAndTheLastWindow() {
        let range = ScrubGesture.range(zoneWidth: 400, current: 1, count: 4)
        XCTAssertEqual(range, -800 ... 400, "one window before it, two after it")
        XCTAssertEqual(ScrubGesture.range(zoneWidth: 400, current: 0, count: 1), 0 ... 0)

        var gesture = ScrubGesture()
        gesture.limit(to: range)
        gesture.add(500, at: 0)
        XCTAssertEqual(gesture.offset, 400, "no further to the right than the first window")
        gesture.add(-100, at: 0.1)
        XCTAssertEqual(gesture.offset, 300, "going back starts at once: the pull past the end is not kept")
        gesture.add(-2000, at: 0.2)
        XCTAssertEqual(gesture.offset, -800)
        XCTAssertEqual(gesture.speed, 0, accuracy: 0.001, "a flick that runs into the end does not carry on")
    }

    func testNewFingersGoOnFromWhereTheContentIsAndForgetTheSpeedOfTheOldSwipe() {
        var gesture = ScrubGesture()
        gesture.limit(to: -800 ... 400)
        gesture.add(-100, at: 0)
        gesture.add(-300, at: 0.05)   // a hard flick
        gesture.resume(at: -150)
        XCTAssertEqual(gesture.offset, -150)
        XCTAssertEqual(gesture.speed, 0)
        gesture.add(-30, at: 1)
        XCTAssertEqual(gesture.offset, -180, "the swipe goes on from there")
        gesture.resume(at: -5000)
        XCTAssertEqual(gesture.offset, -800, "and still within the first and the last window")
    }

    func testLimitsCutWhatTheFingersAlreadyDid() {
        var gesture = ScrubGesture()
        gesture.add(900, at: 0)
        gesture.limit(to: -400 ... 400)
        XCTAssertEqual(gesture.offset, 400)
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

    func testAShortFastSwipeIsAFlickAndASlowOrBackwardOneIsNot() {
        XCTAssertTrue(swipe([(-40, 0), (-40, 0.02), (-40, 0.04)]).isFlick)
        XCTAssertFalse(swipe([(-40, 0), (-40, 0.5)]).isFlick, "too slow")
        XCTAssertFalse(swipe([(-10, 0), (-10, 0.01)]).isFlick, "too short")
        XCTAssertFalse(swipe([(-200, 0), (-50, 0.1), (60, 0.2), (80, 0.25)]).isFlick, "the fingers came back")
    }

    func testAFlickAfterCatchingTheContentCountsFromWhereTheFingersTookHoldAgain() {
        var gesture = swipe([(-300, 0), (-300, 0.5)])    // a long swipe to the left, then the fingers lift
        gesture.resume(at: -600)                          // they catch the glide: the content is taken far to the left of where it began
        gesture.add(60, at: 1.00)
        gesture.add(60, at: 1.02)
        gesture.add(60, at: 1.04)                         // and flick back to the right
        XCTAssertTrue(gesture.isFlick, "a flick back is a flick however far the content already was from the start")
    }
}
