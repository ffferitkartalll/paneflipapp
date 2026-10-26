import AppKit
import SwiftUI

/// The colour the app lights things with: the zone with the focus in the island, the frames, the outlines in the editor and the settings. It is the app's own
/// green, not the accent colour of the system.
struct AppAccent {
    static let red: CGFloat = 0.23
    static let green: CGFloat = 0.91
    static let blue: CGFloat = 0.69

    static let color = Color(red: red, green: green, blue: blue)
    static let nsColor = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    /// What is written or drawn on the colour: it is a light one, so the ink is dark.
    static let ink = Color.black.opacity(0.75)
}
