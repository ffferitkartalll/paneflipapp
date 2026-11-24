import SwiftUI
import XCTest

final class AppearDriverTests: XCTestCase {
    private var time: TimeInterval = 0
    private var seen: [CGFloat] = []
    private var driver: AppearDriver!

    override func setUp() {
        time = 0
        seen = []
        driver = AppearDriver(runsItself: false, clock: { [unowned self] in time }, apply: { [unowned self] in seen.append($0) })
    }

    private func run(_ seconds: TimeInterval, frame: TimeInterval = 1.0 / 120) {
        let end = time + seconds
        while time < end { time += frame; driver.step() }
    }

    func testSlideEndsExactlyAtTargetAndTellsOnce() {
        var told = 0
        driver.slide(to: 1) { told += 1 }
        run(1)
        XCTAssertEqual(driver.value, 1)
        XCTAssertEqual(told, 1)
    }

    func testSlideCutShortByHoldStaysWhereHeldAndTellsNothing() {
        var told = 0
        driver.slide(to: 1) { told += 1 }
        run(0.15)
        let held = driver.value
        driver.hold()
        run(1)
        XCTAssertEqual(driver.value, held)
        XCTAssertEqual(told, 0)
    }

    /// The fingers take hold of a closing slide in the middle and carry the grid up: it never goes past where they put it, nor out of 0...1.
    func testFingersTakingOverAClosingSlideNeverLeaveTheWay() {
        driver.slide(to: 1)
        run(1)
        driver.slide(to: 0)
        run(0.15)
        driver.hold()
        seen = []
        for goal in stride(from: driver.value, through: 1, by: 0.05) { driver.follow(to: goal); run(0.01) }
        driver.follow(to: 0.2)
        run(0.5)
        XCTAssertTrue(seen.allSatisfy { $0 >= 0.2 - 0.0001 && $0 <= 1 })
        XCTAssertEqual(driver.value, 0.2, accuracy: 0.001)
    }

    func testFollowNeverSwingsPastTheGoal() {
        driver.follow(to: 0.9)
        run(0.05)
        driver.follow(to: 0.6)   // the fingers slowed and turned at speed
        run(0.5)
        XCTAssertTrue(seen.allSatisfy { $0 <= 0.9 + 0.0001 && $0 >= 0 })
        XCTAssertEqual(driver.value, 0.6, accuracy: 0.001)
    }

    func testSlideTakenOverByAnotherGoesOnFromWhereItIs() {
        driver.slide(to: 1)
        run(0.1)
        let before = driver.value
        driver.slide(to: 0)
        driver.step()
        XCTAssertEqual(driver.value, before, accuracy: 0.05)
        run(1)
        XCTAssertEqual(driver.value, 0)
    }

    func testSlideTakingOverFromFingersGoesOnAtTheirSpeed() {
        driver.follow(to: 1)
        run(0.1)
        let speedBefore = seen[seen.count - 1] - seen[seen.count - 2]
        driver.follow(to: 0.2)   // the fingers turned: a flick down
        run(0.02)
        driver.slide(to: 0)
        run(1 / 120)
        let step = seen[seen.count - 1] - seen[seen.count - 2]
        XCTAssertLessThan(step, 0, "the grid must not stop before it goes the other way")
        XCTAssertGreaterThan(abs(step), abs(speedBefore) * 0.3, "it takes over at speed, not from rest")
        run(1)
        XCTAssertEqual(driver.value, 0)
        XCTAssertTrue(seen.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testResetGoesBackToZero() {
        driver.slide(to: 1)
        run(1)
        driver.reset()
        XCTAssertEqual(driver.value, 0)
    }
}
