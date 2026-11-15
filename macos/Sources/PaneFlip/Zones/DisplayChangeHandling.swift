/// Told when displays have no layout, or desktops of the displays were removed, before the zones are laid out again.
protocol DisplayChangeHandling: AnyObject {
    /// Every display has at least one layout: one that has none gets the standard one.
    func ensureLayouts(on screens: [ScreenInfo])
    /// Desktops of the displays shown were removed: they no longer hold a layout.
    func desktopsDidChange(on screens: [ScreenInfo])
}
