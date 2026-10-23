import PaneFlipCore

/// What a shortcut asks for.
enum KeyShortcut: Equatable {
    /// Move the zone of the focused window on to its next window (or the previous one).
    case cycle(reverse: Bool)
    /// Move the focus to the zone beside the one of the focused window.
    case focusZone(ZoneDirection)
    /// Scroll toward the zones beyond a screen's edge.
    case scroll(ScreenEdge)
}
