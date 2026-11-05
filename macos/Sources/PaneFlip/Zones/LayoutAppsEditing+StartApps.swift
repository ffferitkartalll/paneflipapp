import PaneFlipCore

extension LayoutAppsEditing {
    /// The apps ticked to be started in the active layout of every display.
    func startApps(on screens: ScreenProviding, in repository: LayoutRepository) -> [String] {
        screens.screens().compactMap { repository.activeLayout(for: $0.key) }.flatMap { startApps(of: $0) }
    }
}
