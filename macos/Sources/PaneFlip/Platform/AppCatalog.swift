import AppKit

/// What the app needs to know about running applications.
protocol AppCatalog {
    func app(pid: pid_t) -> AppInfo?
    /// Running apps that show up in the Dock.
    func regularApps() -> [AppInfo]
    func icon(pid: pid_t) -> NSImage?
}
