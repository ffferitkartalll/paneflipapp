import XCTest

final class PillScrollStepperTests: XCTestCase {
    func testASwipeIsOneStepHoweverManyEventsItHas() {
        var stepper = PillScrollStepper()
        var steps = 0
        for i in 0..<20 { steps += stepper.step(delta: -3, precise: true, at: Double(i) * 0.01) }
        XCTAssertEqual(steps, 1, "twenty events within a swipe: one step on")
    }

    func testTheDirectionFollowsTheScroll() {
        var stepper = PillScrollStepper()
        XCTAssertEqual(stepper.step(delta: 12, precise: true, at: 0), -1, "fingers down: back")
        XCTAssertEqual(stepper.step(delta: -12, precise: true, at: 1), 1, "fingers up: on")
    }

    func testAShortSwipeAddsUpAndAWheelNotchCounts() {
        var stepper = PillScrollStepper()
        XCTAssertEqual(stepper.step(delta: -4, precise: true, at: 0), 0)
        XCTAssertEqual(stepper.step(delta: -7, precise: true, at: 0.01), 1)
        XCTAssertEqual(stepper.step(delta: -1, precise: false, at: 2), 1)
    }

    func testThePillDoesNotListenWhileTheSlideRuns() {
        var stepper = PillScrollStepper()
        XCTAssertEqual(stepper.step(delta: -20, precise: true, at: 0), 1)
        XCTAssertEqual(stepper.step(delta: -20, precise: true, at: 0.2), 0)
        XCTAssertEqual(stepper.step(delta: -20, precise: true, at: 0.5), 1)
    }
}
