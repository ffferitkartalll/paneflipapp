import AppKit
import SwiftUI

/// The line between two zones as the layout editor draws it: thin, white where it stands at a half, a third and the like, the accent colour elsewhere.
/// The mouse goes through it (only the handle takes it).
final class DividerLineView: NSView {
    private let sideBySide: Bool
    var atStep: Bool { didSet { needsDisplay = true } }

    init(sideBySide: Bool, atStep: Bool) {
        self.sideBySide = sideBySide
        self.atStep = atStep
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        (atStep ? NSColor.white : NSColor(AppAccent.color)).setFill()
        (sideBySide ? CGRect(x: bounds.midX - 1, y: 0, width: 2, height: bounds.height) : CGRect(x: 0, y: bounds.midY - 1, width: bounds.width, height: 2)).fill()
    }
}
