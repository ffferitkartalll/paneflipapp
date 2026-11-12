import XCTest
@testable import PaneFlipCore

final class NotchVisibilityTests: XCTestCase {
    private let a = UUID(), b = UUID(), c = UUID()

    func testOnlyTheZoneWithTheFocusHasANotchWhicheverDisplayItIsOn() {
        XCTAssertEqual(NotchVisibility.zones(among: [a, b, c], focused: b, grown: nil), [b])
    }

    func testNoZoneHasOneWhileTheFocusIsInNone() {
        XCTAssertTrue(NotchVisibility.zones(among: [a, b, c], focused: nil, grown: nil).isEmpty)
    }

    func testAZoneThatIsGrownKeepsItsNotchUntilItIsBack() {
        XCTAssertEqual(NotchVisibility.zones(among: [a, b, c], focused: b, grown: a), [a, b])
    }

    func testTheZoneAWindowIsDraggedOutOfHasNoNotchWhileItIsDragged() {
        XCTAssertEqual(NotchVisibility.zones(among: [a, b, c], focused: b, grown: a, dragged: b), [a])
        XCTAssertTrue(NotchVisibility.zones(among: [a, b, c], focused: b, grown: nil, dragged: b).isEmpty)
    }

    func testAZoneOutOfViewHasNone() {
        XCTAssertTrue(NotchVisibility.zones(among: [a, c], focused: b, grown: nil).isEmpty)
    }
}
