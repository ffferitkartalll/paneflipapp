import AppKit

final class FakeApps: AppCatalog {
    var apps: [AppInfo] = []

    func app(pid: pid_t) -> AppInfo? { apps.first { $0.pid == pid } }
    func regularApps() -> [AppInfo] { apps }
    func regularApps(withBundleIDs bundleIDs: Set<String>) -> [AppInfo] { apps.filter { bundleIDs.contains($0.bundleID) } }
    var frontmostPID: pid_t?
    var hidden: Set<pid_t> = []
    func isHidden(pid: pid_t) -> Bool { hidden.contains(pid) }
    func icon(pid: pid_t) -> NSImage? { nil }
    func name(bundleID: String) -> String? { apps.first { $0.bundleID == bundleID }?.name }
    func icon(bundleID: String) -> NSImage? { nil }
    var launched: [String] = []
    func launch(bundleID: String) { launched.append(bundleID) }
    private(set) var quitPIDs: [pid_t] = []
    func hide(pid: pid_t) { hidden.insert(pid) }
    func quit(pid: pid_t) { quitPIDs.append(pid) }
}
