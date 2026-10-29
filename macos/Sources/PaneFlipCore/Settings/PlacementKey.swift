/// A key that works while a window is being sent to a zone through the island: the arrow keys move the choice, Return places the window, Backspace takes
/// it out of its zone, Escape cancels.
public enum PlacementKey: Equatable {
    case move(ZoneDirection)
    case confirm, cancel, remove

    public init?(keyCode: Int) {
        switch keyCode {
        case 123: self = .move(.left)
        case 124: self = .move(.right)
        case 125: self = .move(.down)
        case 126: self = .move(.up)
        case 36, 76: self = .confirm   // Return and the keypad's Enter
        case 53: self = .cancel
        case 51, 117: self = .remove   // Backspace and forward delete
        default: return nil
        }
    }
}
