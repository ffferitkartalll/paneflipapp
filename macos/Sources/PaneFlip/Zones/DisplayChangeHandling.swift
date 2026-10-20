/// Told when displays were plugged in or out, or desktops removed, before the zones are laid out again.
protocol DisplayChangeHandling: AnyObject {
    func displaysDidChange()
    /// Desktops of the displays shown were removed: they no longer hold a layout.
    func desktopsDidChange(on screens: [ScreenInfo])
}
