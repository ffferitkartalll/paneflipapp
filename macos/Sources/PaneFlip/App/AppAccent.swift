import AppKit
import SwiftUI

/// The colour the app lights things with: the zone with the focus in the island, the frames, the outlines in the editor and the settings.
/// With "Multicolor" chosen in the system settings it is the app's own green, with any other colour chosen it is that colour.
struct AppAccent {
    private static let green = NSColor(srgbRed: 0.23, green: 0.91, blue: 0.69, alpha: 1)

    /// "Multicolor" is the system's default: it leaves no `AppleAccentColor` behind.
    static var nsColor: NSColor { UserDefaults.standard.object(forKey: "AppleAccentColor") == nil ? green : .controlAccentColor }
    static var color: Color { Color(nsColor: nsColor) }
    /// The red, green and blue of the colour, for the fill that is mixed with the grey.
    static var rgb: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let c = nsColor.usingColorSpace(.sRGB) ?? green
        return (c.redComponent, c.greenComponent, c.blueComponent)
    }
    /// What is written or drawn on the colour.
    static let ink = Color.black.opacity(0.75)
}
