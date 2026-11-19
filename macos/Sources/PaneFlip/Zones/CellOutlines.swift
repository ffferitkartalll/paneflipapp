import SwiftUI

/// The dashed lines round the places of a grid, all of them one shape: SwiftUI goes through every item it draws at every step of a slide, and a line for each place made the grid
/// late in showing.
struct CellOutlines: Shape {
    let cells: [CGRect]
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for cell in cells {
            // Inside the place, as `strokeBorder` draws it.
            path.addRoundedRect(in: cell.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cornerSize: CGSize(width: 10 - lineWidth / 2, height: 10 - lineWidth / 2), style: .continuous)
        }
        return path
    }
}
