import XCTest
@testable import PaneFlipCore

final class SplitSnapTests: XCTestCase {
    func testALineNearAStepSticksToIt() {
        XCTAssertEqual(SplitSnap.step(near: 0.5 + 10.0 / 1000, extent: 1000, distance: 20), 0.5)
        XCTAssertEqual(SplitSnap.step(near: 0.25 - 5.0 / 1000, extent: 1000, distance: 20), 0.25)
        XCTAssertEqual(SplitSnap.step(near: 2.0 / 3 + 0.01, extent: 1000, distance: 20), 2.0 / 3)
        XCTAssertEqual(SplitSnap.step(near: 3.0 / 4, extent: 1000, distance: 20), 0.75)
        XCTAssertEqual(SplitSnap.step(near: 1.0 / 3, extent: 1000, distance: 20), 1.0 / 3)
    }

    func testALineBetweenStepsMovesFreely() {
        XCTAssertNil(SplitSnap.step(near: 0.4, extent: 1000, distance: 20))
        XCTAssertNil(SplitSnap.step(near: 0.1, extent: 1000, distance: 20))
    }

    func testTheDistanceIsInPointsSoAShortLineHasNarrowerSteps() {
        XCTAssertNil(SplitSnap.step(near: 0.5 + 0.03, extent: 1000, distance: 20))   // 30 pt away
        XCTAssertEqual(SplitSnap.step(near: 0.5 + 0.03, extent: 400, distance: 20), 0.5)   // 12 pt away
    }

    func testTheNearerOfTwoStepsWins() {
        XCTAssertEqual(SplitSnap.step(near: 0.40, extent: 1000, distance: 80), 1.0 / 3)   // 0.067 from a third, 0.1 from a half
        XCTAssertEqual(SplitSnap.step(near: 0.42, extent: 1000, distance: 100), 0.5)
    }

    func testAStepIsNamedAsAShare() {
        XCTAssertEqual(SplitSnap.share(of: 0.25)?.denominator, 4)
        XCTAssertEqual(SplitSnap.share(of: 2.0 / 3)?.numerator, 2)
        XCTAssertEqual(SplitSnap.share(of: 2.0 / 3)?.denominator, 3)
        XCTAssertNil(SplitSnap.share(of: 0.6))
    }

    func testOnlyTheStepsCountAsSteps() {
        XCTAssertTrue(SplitSnap.isStep(2.0 / 3))
        XCTAssertFalse(SplitSnap.isStep(0.6))
    }
}
