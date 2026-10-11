/// Lets collaborators ask for a re-layout without depending on the whole engine.
protocol ZoneRefreshing: AnyObject {
    func refreshZones()
    func restoreWindows()
}
