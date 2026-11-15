import XCTest
import PaneFlipCore

final class StandardShortcutsTests: XCTestCase {
    func testTheZoneWindowsShortcutIsTabOnTheModifierKeysInUse() {
        XCTAssertEqual(StandardShortcuts.values(capsLock: false)[\.zoneWindowsShortcut]?.keys.map(\.name), ["Left Option", "Left Control", "Tab"])
        XCTAssertEqual(StandardShortcuts.values(capsLock: true)[\.zoneWindowsShortcut]?.keys.map(\.name), ["Caps Lock", "Tab"])
        XCTAssertEqual(StandardShortcuts.values(capsLock: false)[\.layoutGridShortcut]?.keys.map(\.name), ["Left Command", "Left Option", "Left Control", "Tab"], "the keys that scroll beyond the edges, and Tab")
        XCTAssertEqual(StandardShortcuts.values(capsLock: true)[\.layoutGridShortcut]?.keys.map(\.name), ["Caps Lock", "Left Shift", "Tab"])
    }
}
