import AppKit

/// What the app needs to know about running applications.
protocol AppCatalog {
    func app(pid: pid_t) -> AppInfo?
    /// Running apps that show up in the Dock.
    func regularApps() -> [AppInfo]
    func icon(pid: pid_t) -> NSImage?
    var frontmostPID: pid_t? { get }
    /// The name and the icon of an installed app, running or not.
    func name(bundleID: String) -> String?
    func icon(bundleID: String) -> NSImage?
    /// Starts an app that is not running, or asks a running one to open a window again (as a click on its Dock icon does),
    /// without bringing it to the front.
    func launch(bundleID: String)
}
