import AppKit

/// The content of a panel that takes the mouse over what is drawn in it (its subviews take none; where nothing is drawn the window server lets the mouse through to the
/// window below), and tells where it was pressed, in screen coordinates.
final class ZonePressView: NSView {
    var onPress: ((CGPoint) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) { onPress?(NSEvent.mouseLocation) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
