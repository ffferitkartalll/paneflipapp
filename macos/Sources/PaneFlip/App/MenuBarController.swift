import AppKit
import Observation
import PaneFlipCore

/// The icon in the menu bar. A left click switches PaneFlip on or off; a right click (or a click with Control held) opens the menu.
/// The icon is filled while PaneFlip is on and only outlined while it is off.
// shortcut: not checked by the compiler; every use is on the main thread (the status item, its clicks and the observation callback).
final class MenuBarController: @unchecked Sendable {
    private let settings: AppSettings
    private let menu: NSMenu
    private var item: NSStatusItem?

    init(settings: AppSettings, menu: NSMenu) {
        self.settings = settings
        self.menu = menu
    }

    func install() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
        refreshIcon()
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // The menu is only attached for this click: with one attached the button would always open it.
            item?.menu = menu
            item?.button?.performClick(nil)
            item?.menu = nil
        } else {
            settings.values.placementEnabled.toggle()
        }
    }

    /// The icon follows the setting, however it is changed (this click, the menu, the Settings window).
    private func refreshIcon() {
        item?.button?.image = NSImage(named: settings.values.placementEnabled ? "MenuBarIcon" : "MenuBarIconOutline")
        withObservationTracking { _ = settings.values.placementEnabled } onChange: { [weak self] in
            DispatchQueue.main.async { self?.refreshIcon() }
        }
    }
}
