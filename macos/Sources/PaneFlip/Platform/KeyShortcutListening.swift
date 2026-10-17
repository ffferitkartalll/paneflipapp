/// The zone-cycling shortcut (Control+Option+Right, Control+Option+Left for the other way), heard anywhere in the system.
/// The key is not passed on to the app in front.
protocol KeyShortcutListening {
    /// Starts listening; `onPress(reverse:)` runs on the main thread. Needs the Accessibility permission.
    func start(onPress: @escaping (_ reverse: Bool) -> Void)
}
