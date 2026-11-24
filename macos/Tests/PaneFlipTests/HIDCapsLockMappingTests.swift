import XCTest

final class HIDCapsLockMappingTests: XCTestCase {
    private func answer(_ pairs: [(dst: Int, src: Int)]) -> String {
        "RegistryID  Key  Value\n" + pairs.map { "1000  UserKeyMapping   (\n        {\n        HIDKeyboardModifierMappingDst = \($0.dst);\n        HIDKeyboardModifierMappingSrc = \($0.src);\n    }\n)\n" }.joined()
    }

    func testOurOwnMappingOnEveryServiceIsOurs() {
        XCTAssertTrue(HIDCapsLockControl.isOnlyOurMapping(answer([(30064771181, 30064771129), (30064771181, 30064771129)])))
    }

    func testAMappingOfTheUserIsNotOurs() {
        XCTAssertFalse(HIDCapsLockControl.isOnlyOurMapping(answer([(30064771181, 30064771129), (30064771300, 30064771129)])), "one foreign key on one service")
        XCTAssertFalse(HIDCapsLockControl.isOnlyOurMapping(answer([(30064771300, 30064771301)])))
    }

    func testNoMappingIsNothingToTakeAway() {
        XCTAssertFalse(HIDCapsLockControl.isOnlyOurMapping("RegistryID  Key  Value\n1000  UserKeyMapping   (\n)\n"))
        XCTAssertFalse(HIDCapsLockControl.isOnlyOurMapping(""))
    }
}
