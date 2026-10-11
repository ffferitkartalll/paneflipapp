import Foundation

/// A zone as the editor draws it: its identity, its number on screen and its rectangle.
struct ZoneRect: Identifiable {
    let id: UUID
    let index: Int
    let rect: CGRect
}
