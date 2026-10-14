import AppKit

/// One app of a layout as the settings show it.
struct LayoutAppEntry: Identifiable {
    /// The slot's place in the memory; stable until the memory changes.
    let slot: Int
    let zoneID: UUID
    let bundleID: String
    let name: String
    let title: String
    let icon: NSImage?

    var id: Int { slot }
}
