import CoreGraphics
import Foundation

/// The card the mouse carries, drawn over the display the pointer is on: the card itself (its picture, or the glyph of its app), as large as its card was, where the
/// pointer holds it, in the room of the display.
struct LayoutGridGhost {
    let card: IslandWindow
    let picture: WindowPicture?
    var size: CGSize
    var at: CGPoint
    /// Whether the picture of the window is shown, or the glyph of the app (a picture is for places of about its own shape).
    var showsPicture: Bool
    /// Lifted a little while it is carried; down once it lands.
    var lifted = true
    /// The grid of the zone the card stands in now: the card is drawn by the view of the cards of a zone's grid, as it is there.
    let model: ZoneWindowsModel

    /// How far the shape of a place may be from the shape of the window (the logarithm of the ratio of their width to height) for the picture to stay.
    static let shapeLimit: CGFloat = 0.25

    static func fits(_ picture: WindowPicture?, in size: CGSize) -> Bool {
        picture.map { abs(log(($0.frame.width / max($0.frame.height, 1)) / (size.width / max(size.height, 1)))) <= shapeLimit } ?? false
    }
}
