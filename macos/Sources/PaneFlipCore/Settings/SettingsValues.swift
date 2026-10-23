import Foundation

/// The persisted shape of the settings.
public struct SettingsValues: Equatable {
    /// Master switch: place apps into zones at all (snapping, remembering, restoring, the pill).
    public var placementEnabled = true
    /// Several apps per zone, switched with the pill. When off, a zone holds one app and a new one replaces it.
    public var stackingEnabled = true
    /// Space between zones in points; not applied to screen edges.
    public var gap = 4.0
    /// A window dragged out of its zone goes back to the size it had before the zone took it in.
    public var restoreSizeOnLeave = true
    /// Space between the zones and the edges of the screen, in points.
    public var edgeMargin = 0.0
    /// Smallest width/height a zone may have, in points.
    public var minZoneSize = 240.0
    /// Show the stack pill at all. When off, windows are still stacked and switched with the keys and the trackpad.
    public var pillEnabled = true
    /// What the stack pill shows for each window.
    public var pillContent = PillContent.icon
    /// The edge of its zone the pill sits along.
    public var pillPosition = PillPosition.top
    /// Show the pill for a zone that holds a single window too (else it appears from two windows on).
    public var pillForSingleWindow = false
    /// Keep the pill in view instead of showing it only while the pointer is over it or the stack changed.
    public var pillAlwaysVisible = false
    /// Look up brand icons for apps on the network (the names of the stacked apps are sent to the icon host).
    public var fetchBrandIcons = true
    /// The mouse's wheel button, held and moved to the side over a zone, moves through its windows.
    public var mouseButtonSwipe = true
    /// Held while dragging a window to highlight zones and snap into one.
    public var snapTrigger = SnapTrigger.leftCommand
    /// The modifier key that, tapped twice, hides the pill under the pointer.
    public var hidePillKey = SnapTrigger.leftCommand
    /// Held while scrolling over a zone, with the mouse wheel or two fingers, to move through its windows.
    public var windowScrollKeys = SnapTrigger.windowScroll
    /// What the trackpad moves through the windows and the zones beyond the screen with.
    public var trackpadMethod = TrackpadMethod.keysAndTwoFingers
    /// How far the content goes for the same stroke of the fingers (two with the keys held, or three and four), as a multiplier of the system's own
    /// trackpad speed.
    public var trackpadSpeed = 2.0
    /// Held while scrolling over the screen, with the mouse wheel or two fingers, to slide to the zones beyond its edges.
    public var stripScrollKeys = SnapTrigger.stripScroll

    /// Bring the next or the previous window of the focused window's zone forward.
    public var nextWindowShortcut = SnapTrigger.nextWindow
    public var previousWindowShortcut = SnapTrigger.previousWindow
    /// Scroll toward the zones beyond the right or left edge of the screen under the pointer.
    public var scrollRightShortcut = SnapTrigger.scrollRight
    public var scrollLeftShortcut = SnapTrigger.scrollLeft

    /// The shortcuts that move the focus to the zone beside the one in focus work at all.
    public var zoneNavigationEnabled = true
    /// Past the last zone on the screen they go on to the zones beyond its edge (the layout scrolls to them).
    public var zoneNavigationBeyondEdges = true
    /// Move the focus to the zone above, to the left, below or to the right of the zone of the focused window.
    public var zoneUpShortcut = SnapTrigger.zoneUp
    public var zoneLeftShortcut = SnapTrigger.zoneLeft
    public var zoneDownShortcut = SnapTrigger.zoneDown
    public var zoneRightShortcut = SnapTrigger.zoneRight

    /// A layout may have zones beyond the left and right edges of a screen. Off: the editor does not show them, scrolling is
    /// off and the apps in them are moved to the screen's default zone.
    public var overflowZonesEnabled = true
    /// Bundle identifiers of apps whose windows PaneFlip leaves alone.
    public var ignoredApps: [String] = []

    /// The language of the app: `systemLanguage` or a language code the string catalog has been translated into.
    public var language = SettingsValues.systemLanguage

    public static let systemLanguage = "system"

    public init() {}
}
