import SwiftUI

/// The arrow of the island when it hangs under the menu bar icon as a popover: a triangle pointing up. Whole, it also covers the line of the rim at its foot;
/// `edgeOnly` is the two sloping sides alone, to stroke.
struct IslandArrow: Shape {
    var edgeOnly = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        if !edgeOnly {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY + 1))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY + 1))
            path.closeSubpath()
        }
        return path
    }
}
