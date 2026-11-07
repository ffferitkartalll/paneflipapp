import SwiftUI

/// The island's edge without its top: down the left side, along the bottom with its rounded corners, up the right side.
struct IslandRim: Shape {
    static let radius: CGFloat = 10

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)  // the stroke (1 pt) lies inside the shape
        let r = Self.radius - 0.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addRelativeArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(180), delta: .degrees(-90))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        path.addRelativeArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), delta: .degrees(-90))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
