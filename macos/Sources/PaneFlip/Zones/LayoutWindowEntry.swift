import AppKit

/// One window of an app in a layout, as the settings show it.
struct LayoutWindowEntry: Identifiable {
    /// The slot's place in the memory; stable until the memory changes.
    let slot: Int
    /// The window's title when last seen; empty when it never had one.
    let title: String

    var id: Int { slot }
}
