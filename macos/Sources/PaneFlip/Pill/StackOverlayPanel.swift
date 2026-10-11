import AppKit
import PaneFlipCore
import SwiftUI

/// The floating panel that hosts a zone's pill. Hidden (and click-through) until the presenter shows it.
final class StackOverlayPanel: NSPanel {
    private let rightMouse: (RightMousePhase, CGFloat) -> Void

    init(stack: ZoneStack, settings: AppSettings,
         select: @escaping (CGWindowID) -> Void,
         rightMouse: @escaping (RightMousePhase, CGFloat) -> Void) {
        self.rightMouse = rightMouse
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        alphaValue = 0
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // A segmented control only looks like Liquid Glass inside a toolbar; wrap ours in AppKit glass instead.
        let glass = NSGlassEffectView()
        glass.contentView = NSHostingView(rootView: StackPillView(stack: stack, settings: settings, select: select))
        glass.cornerRadius = PillMetrics.height / 2
        contentView = glass
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// SwiftUI has no right-drag gesture, so the panel forwards right-button events.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .rightMouseDown: rightMouse(.down, event.locationInWindow.x)
        case .rightMouseDragged: rightMouse(.drag, event.locationInWindow.x)
        case .rightMouseUp: rightMouse(.up, event.locationInWindow.x)
        default: super.sendEvent(event)
        }
    }
}
