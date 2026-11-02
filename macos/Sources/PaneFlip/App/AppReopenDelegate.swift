import AppKit

/// The app is asked to open again while it runs (its Dock icon is clicked, or it is started once more): the Settings window comes up,
/// as it is the only thing the app has to show.
final class AppReopenDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }   // a window is open: the system brings it forward
        SettingsWindowOpener.open()
        return false
    }
}
