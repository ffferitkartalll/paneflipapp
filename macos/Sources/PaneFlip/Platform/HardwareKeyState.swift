import CoreGraphics
import PaneFlipCore

/// Reads the hardware state, so left/right modifiers and ordinary keys all work; the Caps Lock key is the one `CapsLockKeyState` knows.
struct HardwareKeyState: KeyStateProviding {
    let capsLock: CapsLockKeyState

    func isDown(keyCode: Int) -> Bool {
        if keyCode == KeyChord.capsLockKeyCode { return capsLock.isDown }
        return CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode))
    }
}
