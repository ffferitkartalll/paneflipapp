import CoreGraphics
import Foundation

/// A place other than the screen where a dragged window can be dropped on a zone (the island in the menu bar). Points are in Cocoa screen coordinates.
protocol ZoneDropTarget: AnyObject {
    /// A window is being dragged and the pointer is here: the target opens when the pointer is on it and marks the zone under the pointer.
    func dragMoved(to point: CGPoint)
    /// The pointer is on the target, on a zone or not.
    func isOver(_ point: CGPoint) -> Bool
    /// The window is dropped with the pointer here: it goes to the zone under the pointer, and, over the open row of that zone's windows, to the place the row shows.
    func drop(_ window: WindowRef, at point: CGPoint)
    /// The drag is over.
    func dragEnded()
}
