import CoreGraphics

/// Reads the hardware state, so left/right modifiers and ordinary keys all work.
struct HardwareKeyState: KeyStateProviding {
    func isDown(keyCode: Int) -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode))
    }
}
