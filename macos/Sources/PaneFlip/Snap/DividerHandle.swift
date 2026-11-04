import AppKit

/// A line between two zones with its handle: the line is only to be seen, the handle (a small panel of its own) takes the mouse (the pointer keeps its shape) and
/// tells when the mouse goes down, is dragged and comes up.
final class DividerHandle {
    private let linePanel: NSPanel
    private let knobPanel: NSPanel
    private let lineView: DividerLineView
    private let knobView: DividerKnobView
    /// The view that takes the mouse: its three callbacks are what the tests press, drag and let go.
    let mouse: DividerMouseView

    /// `line`: where the line is drawn; `knob`: the middle of the handle (both in Cocoa screen coordinates). `atStep`: the line stands at a half, a third and the like.
    init(line: CGRect, knob: CGPoint, sideBySide: Bool, atStep: Bool, onPress: @escaping () -> Void, onDrag: @escaping () -> Void, onRelease: @escaping () -> Void) {
        linePanel = Self.panel(line)
        linePanel.ignoresMouseEvents = true
        lineView = DividerLineView(sideBySide: sideBySide, atStep: atStep)
        linePanel.contentView = lineView
        lineView.frame = CGRect(origin: .zero, size: line.size)

        let side = DividerKnobView.side
        knobPanel = Self.panel(CGRect(x: knob.x - side / 2, y: knob.y - side / 2, width: side, height: side))
        let view = DividerMouseView(frame: .zero)
        view.onPress = onPress
        view.onDrag = onDrag
        view.onRelease = onRelease
        mouse = view
        view.wantsLayer = true
        // Not quite clear: the window server lets the mouse through the pixels of a window that are fully clear.
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
        knobPanel.contentView = view
        knobPanel.setFrame(CGRect(x: knob.x - side / 2, y: knob.y - side / 2, width: side, height: side), display: true)
        // Added once the view has its size: a view that is resized with a subview in it resizes that too.
        knobView = DividerKnobView(sideBySide: sideBySide, atStep: atStep)
        knobView.frame = view.bounds
        view.addSubview(knobView)

        // Both fade in, at their full length; the line does not grow.
        for panel in [linePanel, knobPanel] {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        }
    }

    /// The line is somewhere else (it is being moved, or a line it meets is): the same panels, moved.
    func update(line: CGRect, knob: CGPoint, atStep: Bool) {
        linePanel.setFrame(line, display: false)
        lineView.frame = CGRect(origin: .zero, size: line.size)
        let side = DividerKnobView.side
        knobPanel.setFrameOrigin(CGPoint(x: knob.x - side / 2, y: knob.y - side / 2))
        lineView.atStep = atStep
        knobView.atStep = atStep
    }

    /// All the lines are drawn first, then all the handles: another line must not run over a handle.
    func raiseHandle() { knobPanel.orderFrontRegardless() }

    private static func panel(_ frame: CGRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        return panel
    }

    func close() {
        knobPanel.ignoresMouseEvents = true   // while it fades
        for panel in [linePanel, knobPanel] {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; panel.animator().alphaValue = 0 }, completionHandler: { panel.orderOut(nil) })
        }
    }
}
