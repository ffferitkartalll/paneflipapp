import XCTest
import CoreGraphics
import PaneFlipCore

final class CGEventFlagsChordTests: XCTestCase {
    func testTheModifierKeysHeldAreTheChordModifiers() {
        let caps = CapsLockKeyState()
        XCTAssertEqual(CGEventFlags([.maskControl, .maskAlternate]).chordModifiers(caps), [.control, .option])
        XCTAssertEqual(CGEventFlags([.maskCommand, .maskShift]).chordModifiers(caps), [.command, .shift])
    }

    func testCapsLockCountsOnlyWhileItsKeyIsDown() {
        let caps = CapsLockKeyState()
        XCTAssertEqual(CGEventFlags([.maskAlphaShift]).chordModifiers(caps), [], "the lock state is not the key")
        caps.isDown = true
        XCTAssertEqual(CGEventFlags([.maskControl]).chordModifiers(caps), [.control, .capsLock])
    }
}
