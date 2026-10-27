import CoreGraphics
import Foundation

/// A remembered app as one layout sees it: the zone of that layout it belongs to and where it stands in the memory,
/// which is also the order of its cards.
public struct LayoutSlot: Equatable {
    public let index: Int
    public let zoneID: UUID
    public let bundleID: String
    public let title: String
    public let windowID: CGWindowID?
}
