/// The shortcuts, heard anywhere in the system: Control+Option+Right (Left for the other way) cycles the zone of the focused
/// window; with Command added, they scroll toward the zones beyond the right (left) edge of the screen. The keys are not passed
/// on to the app in front.
protocol KeyShortcutListening {
    /// Starts listening; `onPress` runs on the main thread. Needs the Accessibility permission.
    func start(onPress: @escaping (KeyShortcut) -> Void)
}
