import AppKit

final class AppKitActivationPolicyController: ActivationPolicyControlling {
    private var openWindows: Set<ObjectIdentifier> = []

    func windowDidOpen(_ window: ObjectIdentifier) {
        let wasEmpty = openWindows.isEmpty
        openWindows.insert(window)
        guard wasEmpty else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)   // so the menu bar shows PaneFlip's menu right away
    }

    func windowDidClose(_ window: ObjectIdentifier) {
        guard openWindows.remove(window) != nil, openWindows.isEmpty else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
