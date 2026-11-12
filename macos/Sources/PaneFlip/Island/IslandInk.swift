import SwiftUI

/// The colour the island is drawn in: white on its black ground, or, when the app is not used as an island and the system's ground is light, black.
struct IslandInk {
    /// The ground is light, so the drawing is dark.
    let light: Bool

    /// The grey of the ink itself: 1 for white, 0 for black.
    var white: Double { light ? 0 : 1 }

    func color(_ opacity: Double = 1) -> Color { Color(white: white).opacity(opacity) }
}
