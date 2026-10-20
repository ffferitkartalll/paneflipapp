import CoreGraphics

/// A display on a particular desktop (Space). Plain values: UI and services never touch NSScreen.
struct ScreenInfo: Identifiable, Equatable {
    /// "displayUUID|d<position>": the key layouts are stored under. A desktop is told by its position among the
    /// display's desktops: the system's own identifier of it changes every time a display is plugged in or out.
    let key: String
    let name: String
    let size: CGSize
    let cocoaFrame: CGRect
    let cocoaVisibleFrame: CGRect
    /// The area below the menu bar and beside the Dock, in top-left-origin (Accessibility) coordinates.
    let axVisible: CGRect
    /// The key this screen's layouts were stored under before (display and the system's desktop identifier).
    var legacyKey: String? = nil
    /// How many ordinary desktops the display has; 0 when the system could not tell.
    var desktopCount = 0

    var id: String { key }

    /// The place of the desktop among the display's desktops; nil for a full-screen space.
    var desktopNumber: Int? { key.split(separator: "|").last.flatMap { $0.first == "d" ? Int($0.dropFirst()) : nil } }

    /// The display itself, whatever its desktop.
    var displayID: String { key.split(separator: "|").first.map(String.init) ?? key }

    /// Changes when the display, its desktop or the area zones are laid out in changes (the Dock moved, the menu
    /// bar was hidden) or the display gains or loses a desktop. The zones are worked out again whenever it changes.
    var layoutSignature: String { "\(key)|\(axVisible)|\(desktopCount)" }
}
