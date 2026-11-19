/// Lets collaborators ask for a re-layout without depending on the whole engine.
protocol ZoneRefreshing: AnyObject {
    func refreshZones()
    /// Only the presenters (the island, the notches) are told the zones changed, nothing is laid out again: for when the windows are held (`StackCoordinator.isScrolling`).
    func refreshPresenters()
    func restoreWindows()
}
