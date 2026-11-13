import XCTest
import PaneFlipCore

final class StandardShortcutsTests: XCTestCase {
    func testTheZoneWindowsShortcutIsTabOnTheModifierKeysInUse() {
        XCTAssertEqual(StandardShortcuts.values(capsLock: false)[\.zoneWindowsShortcut]?.keys.map(\.name), ["Left Option", "Left Control", "Tab"])
        XCTAssertEqual(StandardShortcuts.values(capsLock: true)[\.zoneWindowsShortcut]?.keys.map(\.name), ["Caps Lock", "Tab"])
    }
}
