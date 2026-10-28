import AppKit

/// Opens the Settings window from outside a SwiftUI view. The Settings scene puts a "Settings…" item in the app's main menu, and choosing that item
/// is the one way to open the window without a view to read `openSettings` from; the app becomes a regular app first, as a window of ours does.
enum SettingsWindowOpener {
    static func open() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            guard let menu = NSApp.mainMenu?.items.first?.submenu,
                  let index = menu.items.firstIndex(where: { $0.submenu == nil && $0.action == NSSelectorFromString("menuAction:") && $0.target != nil })
            else { return }
            menu.performActionForItem(at: index)
        }
    }
}
