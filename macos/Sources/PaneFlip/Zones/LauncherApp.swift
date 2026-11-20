import Foundation

/// One app in the launcher of a zone.
struct LauncherApp: Identifiable {
    let bundleID: String
    let name: String

    var id: String { bundleID }
}
