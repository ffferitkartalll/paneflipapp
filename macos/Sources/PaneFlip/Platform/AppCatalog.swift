import AppKit

/// What the app needs to know about running applications.
protocol AppCatalog {
    func app(pid: pid_t) -> AppInfo?
    /// Running apps that show up in the Dock.
    func regularApps() -> [AppInfo]
    func icon(pid: pid_t) -> NSImage?
    /// The name and the icon of an installed app, running or not.
    func name(bundleID: String) -> String?
    func icon(bundleID: String) -> NSImage?
}
