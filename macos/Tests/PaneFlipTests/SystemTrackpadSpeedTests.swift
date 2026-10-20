import XCTest

final class SystemTrackpadSpeedTests: XCTestCase {
    func testAFasterTrackpadTakesTheContentFurtherForTheSameStroke() {
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: 0.6875, multiplier: 2), 6.75, accuracy: 0.0001)
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: 2, multiplier: 2), 12, accuracy: 0.0001)
        XCTAssertGreaterThan(SystemTrackpadSpeed.gain(forTrackingSpeed: 3, multiplier: 2), SystemTrackpadSpeed.gain(forTrackingSpeed: 1, multiplier: 2))
    }

    func testTheSettingMultipliesIt() {
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: 2, multiplier: 4), 24, accuracy: 0.0001)
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: 2, multiplier: 1), 6, accuracy: 0.0001)
    }

    func testValuesOutsideTheSystemsRangeAreHeldInIt() {
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: -4, multiplier: 2), 4)
        XCTAssertEqual(SystemTrackpadSpeed.gain(forTrackingSpeed: 9, multiplier: 2), 16)
    }
}
