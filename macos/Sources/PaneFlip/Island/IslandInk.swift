import SwiftUI

/// The colour the island is drawn in: white on its black ground, or, when the app is not used as an island and the system's ground is light, black.
struct IslandInk {
    /// The ground is light, so the drawing is dark.
    let light: Bool

    /// The grey of the ink itself: 1 for white, 0 for black.
    var white: Double { light ? 0 : 1 }

    func color(_ opacity: Double = 1) -> Color { Color(white: white).opacity(opacity) }

    /// The accent colour on this ground: the island at the notch is black whatever the system's appearance, so it is lit with the colour as it is on a dark ground; the popover
    /// on a light ground with the colour as it is on a light one.
    var accent: Color { light ? AppAccent.color : AppAccent.onDark }
    /// What is written on the accent colour.
    var accentInk: Color { light ? AppAccent.ink : AppAccent.onDarkInk }
    var accentRGB: (red: CGFloat, green: CGFloat, blue: CGFloat) { AppAccent.rgb(dark: !light) }
}
