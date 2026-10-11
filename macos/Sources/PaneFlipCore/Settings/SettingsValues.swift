import Foundation

/// The persisted shape of the settings.
public struct SettingsValues: Equatable {
    public var placementEnabled = true
    public var stackingEnabled = true
    public var gap = 4.0
    public var minZoneSize = 240.0
    public var pillContent = PillContent.icon
    public var snapTrigger = SnapTrigger.leftShift

    public init() {}
}
