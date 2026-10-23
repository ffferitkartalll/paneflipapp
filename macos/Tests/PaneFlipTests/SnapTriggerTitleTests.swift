import XCTest
import PaneFlipCore

final class SnapTriggerTitleTests: XCTestCase {
    func testTheKeysAreShownAsControlOptionShiftCommandAndThenTheKey() {
        let keys: [SnapTrigger.Key] = [.init(code: 124, name: "→"), .init(code: 55, name: "Left Command"), .init(code: 56, name: "Left Shift"),
                                       .init(code: 58, name: "Left Option"), .init(code: 59, name: "Left Control")]
        let title = SnapTrigger(keys: keys).displayTitle
        let parts = title.components(separatedBy: " + ")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts.last, "→")
        XCTAssertEqual(parts[0], SnapTrigger(keys: [keys[4]]).displayTitle)
        XCTAssertEqual(parts[1], SnapTrigger(keys: [keys[3]]).displayTitle)
        XCTAssertEqual(parts[2], SnapTrigger(keys: [keys[2]]).displayTitle)
        XCTAssertEqual(parts[3], SnapTrigger(keys: [keys[1]]).displayTitle)
    }
}
