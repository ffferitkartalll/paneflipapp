import PaneFlipCore

/// What a shortcut asks for.
enum KeyShortcut: Equatable {
    /// Move the zone of the focused window on to its next window (or the previous one).
    case cycle(reverse: Bool)
    /// Move the focus to the zone beside the one of the focused window.
    case focusZone(ZoneDirection)
    /// Scroll toward the zones beyond a screen's edge.
    case scroll(ScreenEdge)
    /// Undo the last action on a window.
    case undoWindow
    /// Enlarge the focused window of a zone for a while.
    case enlargeWindow
    /// Close the message of the island that offers the undo.
    case closeWindowUndoNotice
}
