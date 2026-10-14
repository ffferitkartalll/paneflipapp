import AppKit

/// One window of an app in a layout, as the settings show it.
struct LayoutWindowEntry: Identifiable {
    /// The slot's place in the memory; stable until the memory changes.
    let slot: Int
    /// The window's title when last seen; empty when it never had one.
    let title: String

    var id: Int { slot }
}

/// One app of a layout's zone as the settings show it: a single entry whatever the number of its windows.
struct LayoutAppEntry: Identifiable {
    let zoneID: UUID
    let bundleID: String
    let name: String
    let icon: NSImage?
    /// The open windows, in pill order.
    let windows: [LayoutWindowEntry]

    var id: String { "\(zoneID)/\(bundleID)" }
}
