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
    /// The notch of the display (its width and its height, the height of the menu bar there); 0 on a display without one.
    var notchWidth: CGFloat = 0
    var notchHeight: CGFloat = 0
    /// The size of the display itself in millimetres, as it tells; zero when it does not.
    var physicalSize: CGSize = .zero

    var id: String { key }

    /// The size the display has on the desk, in millimetres: its real size, or (a display that does not tell it) that of a screen with as many points as
    /// this one, at about 110 points to the inch.
    var deskSize: CGSize {
        physicalSize.width > 0 && physicalSize.height > 0 ? physicalSize : CGSize(width: size.width * 25.4 / 110, height: size.height * 25.4 / 110)
    }

    /// The place of the desktop among the display's desktops; nil for a full-screen space.
    var desktopNumber: Int? { key.split(separator: "|").last.flatMap { $0.first == "d" ? Int($0.dropFirst()) : nil } }

    /// The display itself, whatever its desktop.
    var displayID: String { key.split(separator: "|").first.map(String.init) ?? key }

    /// Changes when the display, its desktop or the area zones are laid out in changes (the Dock moved, the menu
    /// bar was hidden) or the display gains or loses a desktop. The zones are worked out again whenever it changes.
    var layoutSignature: String { "\(key)|\(axVisible)|\(desktopCount)" }
}
