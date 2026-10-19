import XCTest
@testable import PaneFlipCore

final class KeyChordTests: XCTestCase {
    func testTheStandardShortcutsAreModifiersAndAnArrow() {
        XCTAssertEqual(KeyChord(.nextWindow), KeyChord(modifiers: [.control, .option], keyCode: 124))
        XCTAssertEqual(KeyChord(.previousWindow), KeyChord(modifiers: [.control, .option], keyCode: 123))
        XCTAssertEqual(KeyChord(.scrollRight), KeyChord(modifiers: [.control, .option, .command], keyCode: 124))
        XCTAssertEqual(KeyChord(.scrollLeft), KeyChord(modifiers: [.control, .option, .command], keyCode: 123))
    }

    func testLeftAndRightModifierKeysCountAlike() {
        let right = SnapTrigger(keys: [.init(code: 62, name: "Right Control"), .init(code: 61, name: "Right Option"), .init(code: 124, name: "→")])
        XCTAssertEqual(KeyChord(right), KeyChord(.nextWindow))
    }

    func testAPlainKeyOrOnlyModifiersOrTwoKeysIsNoShortcut() {
        XCTAssertNil(KeyChord(SnapTrigger(keys: [.init(code: 124, name: "→")])), "a plain key would be taken from every app")
        XCTAssertNil(KeyChord(.leftCommand))
        XCTAssertNil(KeyChord(SnapTrigger(keys: [.init(code: 59, name: "Left Control"), .init(code: 0, name: "A"), .init(code: 11, name: "B")])))
    }
}
