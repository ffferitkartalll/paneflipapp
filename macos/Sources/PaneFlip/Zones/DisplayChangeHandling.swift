/// Told when desktops of the displays were removed, before the zones are laid out again.
protocol DisplayChangeHandling: AnyObject {
    /// Desktops of the displays shown were removed: they no longer hold a layout.
    func desktopsDidChange(on screens: [ScreenInfo])
}
