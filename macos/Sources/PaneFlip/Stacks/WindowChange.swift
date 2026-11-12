import CoreGraphics
import Foundation

/// One action on a window that can be undone (for now: added to a zone, taken out of one, enlarged), and what undoing it needs.
struct WindowChange {

    let kind: Kind
    let window: WindowRef
    /// The window's title when the change was made.
    let title: String
    /// The zone the change is told about: the one the window went into, or came out of.
    let zone: UUID
    /// Where the window was before: its zone, or, when it had none, the frame it stood at.
    let zoneBefore: UUID?
    let frameBefore: CGRect?
    /// The slots that stood right before and right after the window's in its zone (open or not), so that undoing the change puts it back between them, not at the end.
    var slotBefore: UUID? = nil
    var slotAfter: UUID? = nil
}
