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
    /// The edge of its zone the pill sits along.
    public var pillPosition = PillPosition.top
    /// Show the pill for a zone that holds a single window too (else it appears from two windows on).
    public var pillForSingleWindow = false
    /// Look up brand icons for apps on the network (the names of the stacked apps are sent to the icon host).
    public var fetchBrandIcons = true
    /// Held while dragging a window to highlight zones and snap into one.
    public var snapTrigger = SnapTrigger.leftCommand
    /// The modifier key that, tapped twice, hides the pill under the pointer.
    public var hidePillKey = SnapTrigger.leftCommand

    /// Bring the next or the previous window of the focused window's zone forward.
    public var nextWindowShortcut = SnapTrigger.nextWindow
    public var previousWindowShortcut = SnapTrigger.previousWindow
    /// Scroll toward the zones beyond the right or left edge of the screen under the pointer.
    public var scrollRightShortcut = SnapTrigger.scrollRight
    public var scrollLeftShortcut = SnapTrigger.scrollLeft

    /// A layout may have zones beyond the left and right edges of a screen. Off: the editor does not show them, scrolling is
    /// off and the apps in them are moved to the screen's default zone.
    public var overflowZonesEnabled = true

    /// The language of the app: `systemLanguage` or a language code the string catalog has been translated into.
    public var language = SettingsValues.systemLanguage

    public static let systemLanguage = "system"

    public init() {}
}
