import CoreGraphics

/// A display on a particular desktop (Space). Plain values: UI and services never touch NSScreen.
struct ScreenInfo: Identifiable, Equatable {
    /// "displayUUID|desktopID": the key layouts are stored under.
    let key: String
    let name: String
    let size: CGSize
    let cocoaFrame: CGRect
    let cocoaVisibleFrame: CGRect
    /// The area below the menu bar and beside the Dock, in top-left-origin (Accessibility) coordinates.
    let axVisible: CGRect

    var id: String { key }
}
