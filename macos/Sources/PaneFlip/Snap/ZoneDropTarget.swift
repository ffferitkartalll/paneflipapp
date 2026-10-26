import CoreGraphics
import Foundation

/// A place other than the screen where a dragged window can be dropped on a zone (the island in the menu bar). Points are in Cocoa screen coordinates.
protocol ZoneDropTarget: AnyObject {
    /// A window is being dragged and the pointer is here: the target opens when the pointer is on it and marks the zone under the pointer.
    func dragMoved(to point: CGPoint)
    /// The pointer is on the target, on a zone or not.
    func isOver(_ point: CGPoint) -> Bool
    /// The zone under the pointer, when it is on the target.
    func zone(at point: CGPoint) -> UUID?
    /// The drag is over.
    func dragEnded()
}
