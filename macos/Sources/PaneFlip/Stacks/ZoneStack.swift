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

    init(id: UUID) { self.id = id }

    var isEmpty: Bool { tabs.isEmpty }

    func refreshNames() {
        let names = TabNaming.displayNames(for: tabs.map { .init(appName: $0.appName, title: $0.title) })
        for (i, name) in names.enumerated() where tabs[i].displayName != name { tabs[i].displayName = name }
    }
}
