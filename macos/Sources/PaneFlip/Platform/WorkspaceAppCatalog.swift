import AppKit

final class WorkspaceAppCatalog: AppCatalog {
    func app(pid: pid_t) -> AppInfo? {
        NSRunningApplication(processIdentifier: pid).map(info)
    }

    /// An app's activation policy, as it was asked once: reading it is a round trip to the system's launch service (several ms for each running app),
    /// and it rarely changes while an app runs.
    private var policies: [pid_t: NSApplication.ActivationPolicy] = [:]

    func regularApps() -> [AppInfo] {
        let running = NSWorkspace.shared.runningApplications
        policies = policies.filter { pid, _ in running.contains { $0.processIdentifier == pid } }
        return running.filter { app in
            let pid = app.processIdentifier
            if policies[pid] == nil { policies[pid] = app.activationPolicy }
            return policies[pid] == .regular
        }.map(info)
    }

    var frontmostPID: pid_t? { NSWorkspace.shared.frontmostApplication?.processIdentifier }

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
