import AppKit
import SwiftUI

/// The round handle of a line between two zones, as the layout editor and the desktop show it: two bars (an equal sign across a line that runs the other way),
/// on white where the line stands at a half, a third and the like, and on the accent colour elsewhere. The mouse goes through the view, to the view behind.
final class DividerKnobView: NSView {
    static let side: CGFloat = 24
    private let sideBySide: Bool
    private var picture: NSImage
    /// The line stands on a step (a half, a third and the like).
    var atStep: Bool {
        didSet {
            picture = Self.image(sideBySide: sideBySide, atStep: atStep)
            needsDisplay = true
        }
    }

    init(sideBySide: Bool, atStep: Bool) {
        self.sideBySide = sideBySide
        self.atStep = atStep
        picture = Self.image(sideBySide: sideBySide, atStep: atStep)
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) { picture.draw(in: bounds) }

    /// The handle as a picture: the one the desktop and the layout editor both draw, so that they cannot differ.
    static func image(sideBySide: Bool, atStep: Bool) -> NSImage {
        NSImage(size: CGSize(width: side, height: side), flipped: false) { bounds in
            (atStep ? NSColor.white : NSColor(AppAccent.color)).setFill()
            NSBezierPath(ovalIn: bounds).fill()
            let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold).applying(.init(paletteColors: [atStep ? .black : .white]))
            guard let symbol = NSImage(systemSymbolName: sideBySide ? "pause" : "equal", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else { return true }
            symbol.draw(in: CGRect(x: bounds.midX - symbol.size.width / 2, y: bounds.midY - symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height))
            return true
        }
    }
}
