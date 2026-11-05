import CoreGraphics

/// What a card of the island's windows row offers while the mouse is over it (the island open under the pointer): in the order of the buttons.
enum IslandCardAction: CaseIterable {
    /// The first four stand in the top left corner; `remove` (takes the window out of its zone, the window itself stays open) in the top right one.
    case quit, close, hide, minimize, remove

    var symbol: String {
        switch self {
        case .quit: "power"
        case .close: "xmark"
        case .hide: "eye.slash"
        case .minimize: "minus"
        case .remove: "trash"
        }
    }

    private static let margin: CGFloat = 4, gap: CGFloat = 4
    /// As large as when all are shown.
    private static func side(in card: CGSize) -> CGFloat {
        let count = CGFloat(allCases.count)
        return min(20, max(6, floor((card.width - 2 * margin - count * gap) / count)))
    }

    /// The button in the bottom right corner that ticks the card's app to be started with the layout, as large as the others.
    static func selectRect(in card: CGSize) -> CGRect {
        let side = side(in: card)
        return CGRect(x: card.width - margin - side, y: card.height - margin - side, width: side, height: side)
    }

    /// Where the buttons stand in a card of this size, from its top left corner; smaller when the card is narrow.
    /// `actions` are those the card shows (in the order of `allCases`); the buttons are as large as when all are shown.
    static func rects(in card: CGSize, among actions: [IslandCardAction] = allCases) -> [(action: IslandCardAction, rect: CGRect)] {
        let side = side(in: card)
        let left = actions.filter { $0 != .remove }
        return actions.map { action in
            let x = action == .remove ? card.width - margin - side : margin + CGFloat(left.firstIndex(of: action) ?? 0) * (side + gap)
            return (action, CGRect(x: x, y: margin, width: side, height: side))
        }
    }
}
