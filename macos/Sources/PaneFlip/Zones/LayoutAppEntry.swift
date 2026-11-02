import AppKit

/// One app of a layout's zone as the settings show it: a single entry whatever the number of its windows.
struct LayoutAppEntry: Identifiable {
    let zoneID: UUID
    let bundleID: String
    let name: String
    let icon: NSImage?
    /// The open windows, in the island's order.
    let windows: [LayoutWindowEntry]

    var id: String { "\(zoneID)/\(bundleID)" }
}
