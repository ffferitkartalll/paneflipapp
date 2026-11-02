/// The Caps Lock key as a modifier key of the app: mapped away from the lock (to F18, which the shortcuts then read as
/// Caps Lock), with the lock itself kept on Command and Caps Lock together.
protocol CapsLockControlling {
    /// Maps the Caps Lock key to F18 (on) or gives it back to the system (off). Asked again for the state it is in, it does nothing.
    func remap(_ enabled: Bool)
    /// Turns the Caps Lock state (the capital letters) on, or off when it is on.
    func toggleLock()
}
