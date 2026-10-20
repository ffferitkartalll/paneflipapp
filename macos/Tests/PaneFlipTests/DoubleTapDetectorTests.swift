import XCTest

final class DoubleTapDetectorTests: XCTestCase {
    private var taps = 0
    private lazy var detector = DoubleTapDetector(keyCode: { 55 }, interval: 0.4) { [unowned self] in taps += 1 }
    private let start = Date(timeIntervalSinceReferenceDate: 1000)

    func testTwoQuickTapsCount() {
        detector.modifierWentDown(at: start)
        detector.modifierWentDown(at: start.addingTimeInterval(0.2))
        XCTAssertEqual(taps, 1)
    }

    func testTwoSlowTapsDoNot() {
        detector.modifierWentDown(at: start)
        detector.modifierWentDown(at: start.addingTimeInterval(0.6))
        XCTAssertEqual(taps, 0)
    }

    func testAKeyPressedBetweenMakesItAShortcutNotATap() {
        detector.modifierWentDown(at: start)           // Command+C
        detector.otherKeyWentDown()
        detector.modifierWentDown(at: start.addingTimeInterval(0.2))   // Command+V
        XCTAssertEqual(taps, 0)
        detector.modifierWentDown(at: start.addingTimeInterval(0.3))   // and now two bare taps still count
        XCTAssertEqual(taps, 1)
    }
}
