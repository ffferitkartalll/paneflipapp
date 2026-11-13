import XCTest
@testable import PaneFlipCore

final class NotchSwitchResponseTests: XCTestCase {
    func testASwitchGrowsTheNotchUnlessItOpensOnAClickOnly() {
        XCTAssertEqual(NotchSwitchResponse.of(opensOnClickOnly: false, liftsOnSwitch: true, grown: false), .grow)
        XCTAssertEqual(NotchSwitchResponse.of(opensOnClickOnly: false, liftsOnSwitch: false, grown: false), .grow, "the second setting only counts with the first")
    }

    func testOpeningOnAClickOnlyTheNotchStaysClosedOrIsLitForTheSwitchAsAsked() {
        XCTAssertEqual(NotchSwitchResponse.of(opensOnClickOnly: true, liftsOnSwitch: true, grown: false), .lift)
        XCTAssertEqual(NotchSwitchResponse.of(opensOnClickOnly: true, liftsOnSwitch: false, grown: false), .stay)
    }

    func testANotchThatWasClickedOpenGoesOnFollowingTheSwitches() {
        XCTAssertEqual(NotchSwitchResponse.of(opensOnClickOnly: true, liftsOnSwitch: false, grown: true), .grow)
    }
}
