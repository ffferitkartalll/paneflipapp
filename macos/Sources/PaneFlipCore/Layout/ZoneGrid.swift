import CoreGraphics

/// The cards of a zone's windows laid out as a square grid, as Mission Control lays out windows, in the room of one zone.
public enum ZoneGrid {
    /// No grid is smaller than 2 by 2.
    public static let least = 2

    /// How many cards stand in a row (and in a column): 2 for up to four cards, 3 for up to nine, 4 for up to sixteen, and so on.
    public static func side(forCards count: Int) -> Int {
        max(least, Int(Double(max(count, 1)).squareRoot().rounded(.up)))
    }

    /// The cells of `count` cards in `size`, row by row from the top left: every cell is as large as one of the side × side cells of the whole grid is (so a card is as
    /// large with one more window as with one less), exactly `gap` between the cells, along the rows and between them, and none between the grid and the edges of `size`:
    /// a full row and a full column reach them. A card has the shape the room leaves it, which is not quite the shape of the zone.
    public static func cells(count: Int, in size: CGSize, gap: CGFloat) -> [CGRect] {
        guard count > 0, size.width > 0, size.height > 0 else { return [] }
        let side = side(forCards: count), n = CGFloat(side)
        let width = max((size.width - (n - 1) * gap) / n, 0), height = max((size.height - (n - 1) * gap) / n, 0)
        return (0 ..< count).map { i in
            CGRect(x: CGFloat(i % side) * (width + gap), y: CGFloat(i / side) * (height + gap), width: width, height: height)
        }
    }

    /// The card an arrow key goes to from the card `index` (`columns` to the right, `rows` down; negative: left, up) among `count` cards: one step along the grid, and not
    /// past its edge; in the last row, which may not be full, the last card where the column has none.
    public static func moved(from index: Int, columns: Int, rows: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let side = side(forCards: count), lastRow = (count - 1) / side
        let row = min(max(index / side + rows, 0), lastRow), column = min(max(index % side + columns, 0), side - 1)
        return min(row * side + column, count - 1)
    }

    /// The cell a point is in, or, in the gaps and outside, the nearest one: where a card carried over the grid would be put down.
    public static func index(at point: CGPoint, in cells: [CGRect]) -> Int? {
        guard !cells.isEmpty else { return nil }
        func distance(_ rect: CGRect) -> CGFloat {
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX), dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return dx * dx + dy * dy
        }
        return cells.indices.min { distance(cells[$0]) < distance(cells[$1]) }
    }
}
