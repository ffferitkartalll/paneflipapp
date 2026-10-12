import AppKit

final class WorkspaceAppCatalog: AppCatalog {
    func app(pid: pid_t) -> AppInfo? {
        NSRunningApplication(processIdentifier: pid).map(info)
    }

    func regularApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(info)
    }

    func icon(pid: pid_t) -> NSImage? {
        NSRunningApplication(processIdentifier: pid)?.icon
    }

    private func info(_ a: NSRunningApplication) -> AppInfo {
        AppInfo(pid: a.processIdentifier, bundleID: a.bundleIdentifier ?? "", name: a.localizedName ?? "?")
    }
}
