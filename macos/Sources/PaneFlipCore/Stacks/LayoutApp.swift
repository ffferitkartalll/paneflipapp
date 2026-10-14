import Foundation

/// An app of one layout's zone: all its windows' slots, in pill order. The settings list apps, not windows.
public struct LayoutApp: Equatable {
    public let zoneID: UUID
    public let bundleID: String
    public let slots: [LayoutSlot]
}
