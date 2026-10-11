import PaneFlipCore

extension SnapTrigger {
    /// True while every key of the trigger is held.
    func isHeld(using keys: KeyStateProviding) -> Bool {
        !self.keys.isEmpty && self.keys.allSatisfy { keys.isDown(keyCode: $0.code) }
    }
}
