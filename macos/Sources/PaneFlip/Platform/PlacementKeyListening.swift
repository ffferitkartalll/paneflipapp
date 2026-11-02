import PaneFlipCore

/// Hears the shortcut that begins the choice of a zone, and, only while a choice is being made, the keys that move, confirm or cancel it.
protocol PlacementKeyListening {
    func start(onEvent: @escaping (PlacementEvent) -> Void)
}
