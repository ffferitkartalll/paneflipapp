import SwiftUI

/// The edge and the shadow of a card (a picture of a window in the grid, the launcher, the search bar) as macOS gives a window that is not in focus, in the dark and in the light
/// appearance: a light line inside the edge, a dark one outside it, and a shadow; and the buttons over a card's picture.
enum CardEdge {
    static let inner = Color(light: .white.opacity(0.5), dark: .white.opacity(0.08))
    static let outer = Color(light: .black.opacity(0.22), dark: .black.opacity(0.85))
    static let shadow = Color(light: .black.opacity(0.3), dark: .black.opacity(0.5))
    /// What the plain shape that casts the shadow is filled with: it shows through a card that is not opaque.
    static let ground = Color.canvas

    /// The round buttons over the picture of a card (the notch's cards, the layout cards of the settings): dark with a light picture on them, light in the light appearance.
    static func buttonFill(hover: Bool) -> Color { Color(light: .white.opacity(hover ? 0.9 : 0.7), dark: .black.opacity(hover ? 0.85 : 0.6)) }
    static let buttonGlyph = Color.contrast
}
