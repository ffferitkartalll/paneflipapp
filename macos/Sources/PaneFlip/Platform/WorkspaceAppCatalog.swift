import AppKit

final class WorkspaceAppCatalog: AppCatalog {
    private static let iconSize = NSSize(width: 32, height: 32)

    func app(pid: pid_t) -> AppInfo? {
        NSRunningApplication(processIdentifier: pid).map(info)
    }

    func regularApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(info)
    }

    func icon(pid: pid_t) -> NSImage? {
        let icon = NSRunningApplication(processIdentifier: pid)?.icon?.copy() as? NSImage
        icon?.size = Self.iconSize
        return icon
    }

    private func info(_ a: NSRunningApplication) -> AppInfo {
        AppInfo(pid: a.processIdentifier, bundleID: a.bundleIdentifier ?? "", name: a.localizedName ?? "?")
    }
}
