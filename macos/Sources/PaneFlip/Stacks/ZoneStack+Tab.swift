import AppKit
import Observation
import PaneFlipCore

extension ZoneStack {
    struct Tab: Identifiable {
        let id: CGWindowID
        var title: String
        let appName: String
        let bundleID: String
        let icon: NSImage?
        /// What the island shows: the app name, plus the window title when the zone holds several windows of that app.
        var displayName = ""
    }
}
