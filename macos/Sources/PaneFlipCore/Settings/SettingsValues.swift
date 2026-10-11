import Foundation

/// The persisted shape of the settings.
public struct SettingsValues: Equatable {
    /// Master switch: place apps into zones at all (snapping, remembering, restoring, the pill).
    public var placementEnabled = true
    /// Several apps per zone, switched with the pill. When off, a zone holds one app and a new one replaces it.
    public var stackingEnabled = true
    /// Space between zones in points; not applied to screen edges.
    public var gap = 4.0
    /// Smallest width/height a zone may have, in points.
    public var minZoneSize = 240.0
    /// What the stack pill shows for each window.
    public var pillContent = PillContent.icon
    /// Held while dragging a window to highlight zones and snap into one.
    public var snapTrigger = SnapTrigger.leftShift

    public init() {}
}
