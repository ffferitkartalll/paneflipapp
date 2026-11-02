import PaneFlipCore

/// What happens at the keys that send a window to a zone through the island.
enum PlacementEvent: Equatable {
    /// The modifier keys of the shortcut are held, and no others.
    case chord
    /// A key of the choice, while one is being made.
    case key(PlacementKey)
}
