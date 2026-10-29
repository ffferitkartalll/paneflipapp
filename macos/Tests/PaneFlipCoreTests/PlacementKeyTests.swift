import XCTest
import PaneFlipCore

final class PlacementKeyTests: XCTestCase {
    func testTheKeysOfTheChoiceAreNamedByKeyCode() {
        XCTAssertEqual(PlacementKey(keyCode: 123), .move(.left))
        XCTAssertEqual(PlacementKey(keyCode: 124), .move(.right))
        XCTAssertEqual(PlacementKey(keyCode: 125), .move(.down))
        XCTAssertEqual(PlacementKey(keyCode: 126), .move(.up))
        XCTAssertEqual(PlacementKey(keyCode: 36), .confirm)
        XCTAssertEqual(PlacementKey(keyCode: 76), .confirm, "the keypad's Enter")
        XCTAssertEqual(PlacementKey(keyCode: 53), .cancel)
        XCTAssertEqual(PlacementKey(keyCode: 51), .remove, "Backspace")
        XCTAssertEqual(PlacementKey(keyCode: 117), .remove, "forward delete")
        XCTAssertNil(PlacementKey(keyCode: 0))
    }

    func testTheModifierKeysOfTheShortcutAreTakenFromItsKeys() {
        XCTAssertEqual(KeyChord.modifiers(of: .sendToZone), [.shift, .option, .control])
        XCTAssertNil(KeyChord.modifiers(of: .nextWindow), "an arrow key is not a modifier")
        XCTAssertNil(KeyChord.modifiers(of: SnapTrigger(keys: [])))
    }
}
