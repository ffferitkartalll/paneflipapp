import SwiftUI

/// The colour the app lights things with: the zone with the focus in the island, the frames, the outlines in the editor and the settings.
/// With "Multicolor" chosen in the system settings it is the app's own green, with any other colour chosen it is that colour. The own green is the mint of the app icon's upper
/// edge on a dark ground and the deeper green of its lower edge (darkened until text in it reads: 4.9 to 1 against white) on a light one.
struct AppAccent {
    static let mint = NSColor(srgbRed: 0.23, green: 0.91, blue: 0.69, alpha: 1)
    static let deep = NSColor(srgbRed: 0, green: 0.50, blue: 0.37, alpha: 1)

    /// "Multicolor" is the system's default: it leaves no `AppleAccentColor` behind.
    private static var isMulticolor: Bool { UserDefaults.standard.object(forKey: "AppleAccentColor") == nil }

    static var nsColor: NSColor { isMulticolor ? NSColor(light: deep, dark: mint) : .controlAccentColor }
    static var color: Color { Color(nsColor: nsColor) }
    /// What is written or drawn on the colour: white on the deep green, dark on the mint and on a colour the user chose.
    static var ink: Color { isMulticolor ? Color(light: .white, dark: onDarkInk) : onDarkInk }

    /// The colour as it is on a dark ground whatever the system's appearance: the island at the notch is black in both, and is lit with this.
    static var onDark: Color { Color(nsColor: onDarkNSColor) }
    private static var onDarkNSColor: NSColor { isMulticolor ? mint : .controlAccentColor }
    static let onDarkInk = Color.black.opacity(0.75)
    /// The red, green and blue of the colour in the light or the dark appearance, for the fill that is mixed with the grey.
    static func rgb(dark: Bool) -> (red: CGFloat, green: CGFloat, blue: CGFloat) { (dark ? onDarkNSColor : nsColor).rgb(dark: dark) }
    /// The zone a window is being sent to, lit in the island while the choice is made.
    static let placement = Color(red: 1, green: 0.62, blue: 0.04)
}
