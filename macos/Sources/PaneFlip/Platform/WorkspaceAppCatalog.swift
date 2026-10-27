import AppKit

final class WorkspaceAppCatalog: AppCatalog {
    func app(pid: pid_t) -> AppInfo? {
        NSRunningApplication(processIdentifier: pid).map(info)
    }

    func regularApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(info)
    }

    /// Reading anything of a running app is a round trip to the system's launch service (several ms for each), so the few that are wanted are
    /// asked for by name instead of looking at all of them.
    func regularApps(withBundleIDs bundleIDs: Set<String>) -> [AppInfo] {
        bundleIDs.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }.filter { $0.activationPolicy == .regular }.map(info)
    }

    var frontmostPID: pid_t? { NSWorkspace.shared.frontmostApplication?.processIdentifier }

    func isHidden(pid: pid_t) -> Bool { NSRunningApplication(processIdentifier: pid)?.isHidden ?? false }

    func icon(pid: pid_t) -> NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }

    /// A running app is asked first, so a name or an icon is the very one the pill uses for it.
    func name(bundleID: String) -> String? {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName {
            return running
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let bundle = Bundle(url: url)
        return (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
    }

    func icon(bundleID: String) -> NSImage? {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon { return running }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    func launch(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func info(_ a: NSRunningApplication) -> AppInfo {
        AppInfo(pid: a.processIdentifier, bundleID: a.bundleIdentifier ?? "", name: a.localizedName ?? "?")
    }
}
