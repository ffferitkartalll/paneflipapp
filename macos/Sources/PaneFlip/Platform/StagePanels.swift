import AppKit

/// The transparent, click-through panels that the stages draw on: one per screen, always on screen.
final class StagePanels {
    private var panels: [CGDirectDisplayID: NSPanel] = [:]

    /// The panel of a screen, made once.
    func panel(for screen: NSScreen) -> NSPanel {
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        if let panel = panels[id] {
            // A screen that was moved or changed its size: the panel goes with it.
            if panel.frame != screen.frame { panel.setFrame(screen.frame, display: false) }
            return panel
        }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Above the windows, below the pills (which are floating).
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // AppKit scales a window up (and fades it) when it is ordered in: the picture would shrink and grow back.
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        panel.contentView = view
        panel.orderFrontRegardless()
        panels[id] = panel
        return panel
    }
}
