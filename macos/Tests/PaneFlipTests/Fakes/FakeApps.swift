import AppKit

final class FakeApps: AppCatalog {
    var apps: [AppInfo] = []

    func app(pid: pid_t) -> AppInfo? { apps.first { $0.pid == pid } }
    func regularApps() -> [AppInfo] { apps }
    func icon(pid: pid_t) -> NSImage? { nil }
    func name(bundleID: String) -> String? { apps.first { $0.bundleID == bundleID }?.name }
    func icon(bundleID: String) -> NSImage? { nil }
}
