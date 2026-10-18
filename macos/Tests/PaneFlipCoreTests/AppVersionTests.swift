import XCTest
@testable import PaneFlipCore

final class AppVersionTests: XCTestCase {
    func testVersionsAreComparedNumberByNumber() throws {
        XCTAssertLessThan(try XCTUnwrap(AppVersion("1.9")), try XCTUnwrap(AppVersion("1.10")))
        XCTAssertLessThan(try XCTUnwrap(AppVersion("1.0")), try XCTUnwrap(AppVersion("1.0.1")))
        XCTAssertEqual(AppVersion("1.0"), AppVersion("1.0.0"))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("2.0")), try XCTUnwrap(AppVersion("1.99.9")))
    }

    func testALeadingVIsAllowedAndNothingElse() {
        XCTAssertEqual(AppVersion("v1.2.3")?.description, "1.2.3")
        XCTAssertNil(AppVersion("1.2-beta"))
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("1..2"))
        XCTAssertNil(AppVersion("latest"))
    }
}
