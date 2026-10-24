import AppKit
import Observation
import PaneFlipCore

/// The live state of one zone: which windows are stacked in it and how the pill is being used.
/// Observable, so the pill redraws itself when it changes.
@Observable
final class ZoneStack {
    struct Tab: Identifiable {
        let id: CGWindowID
        var title: String
        let appName: String
        let bundleID: String
        let icon: NSImage?
        /// What the pill shows: the app name, plus the window title when the zone holds several windows of that app.
        var displayName = ""
    }

    let id: UUID
    var tabs: [Tab] = []
    var activeID: CGWindowID? {
        didSet { if let id = activeID { mru.removeAll { $0 == id }; mru.insert(id, at: 0) } }
    }

    /// True while the pill is being pressed or scrubbed, so it stays visible.
    @ObservationIgnored var interacting = false

    /// Windows of this zone, most recently active first.
    @ObservationIgnored var mru: [CGWindowID] = []
    @ObservationIgnored var refs: [CGWindowID: WindowRef] = [:]
    /// Zone rectangle in top-left-origin (Accessibility) coordinates.
    @ObservationIgnored var rect: CGRect = .zero
    /// Where the windows of this zone stand: `rect`, or a waiting place at a display's edge while the zone is scrolled
    /// out of sight.
    @ObservationIgnored var frame: CGRect = .zero
    @ObservationIgnored var isParked = false
    /// The zone floats over another one (see `FloatingZone`); its windows go to `awayFrame` while the focus is elsewhere.
    @ObservationIgnored var isFloating = false
    @ObservationIgnored var awayFrame: CGRect?
    /// The window in view in a floating zone: the one with the focus. The others, and all of them when the focus is elsewhere, wait at `awayFrame`.
    @ObservationIgnored var shownID: CGWindowID?
    /// Counts the changes of the window in view: pictures taken for an earlier change are not shown for a later one.
    @ObservationIgnored var changes = 0
    /// The number the zone shows in its layout.
    @ObservationIgnored var number = 0

    init(id: UUID) { self.id = id }

    var isEmpty: Bool { tabs.isEmpty }
    /// A floating zone with nothing in view, which has a place beyond the edge to wait at.
    var isAway: Bool { isFloating && awayFrame != nil && !isParked && shownID == nil }

    func refreshNames() {
        let names = TabNaming.displayNames(for: tabs.map { .init(appName: $0.appName, title: $0.title) })
        for (i, name) in names.enumerated() where tabs[i].displayName != name { tabs[i].displayName = name }
    }
}
