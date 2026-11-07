import Foundation

/// Where the card carried out of the row would go if let go now: onto the island (as a dragged window would: a zone of the picture, or a place in the open row of
/// another zone), onto a zone of the screen (the zones light up), or out of its zone (reverse snap).
enum IslandCarryTarget: Equatable {
    case island, screen(UUID), takeOut

    /// Like a window dragged with the snap trigger held: every zone of the screen stays lit while the card is over the screen (also in a gap and when it would
    /// be taken out of its zone), and the one under the pointer is marked (none in a gap).
    var lighting: (lit: Bool, zone: UUID?) {
        switch self {
        case .island: (false, nil)
        case .screen(let zone): (true, zone)
        case .takeOut: (true, nil)
        }
    }
}
