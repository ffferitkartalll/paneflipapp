import CoreGraphics
import Foundation

/// A zone of the grid of a whole layout: where it stood when the grid opened, in the room of the display (beyond its edges for a screen beyond them), and the grid of
/// its windows, which is what the grid of one zone shows (`ZoneWindowsModel`).
struct LayoutGridZone: Identifiable {
    let id: UUID
    let rect: CGRect
    let model: ZoneWindowsModel
}
