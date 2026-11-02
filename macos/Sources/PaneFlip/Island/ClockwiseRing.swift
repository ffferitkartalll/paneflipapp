import AppKit
import PaneFlipCore
import SwiftUI

/// A rounded rectangle drawn from the middle of its top edge, clockwise: trimmed, it runs down from twelve o'clock like a clock's hand.
struct ClockwiseRing: InsettableShape {
    let radius: CGFloat
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> ClockwiseRing { ClockwiseRing(radius: radius, inset: inset + amount) }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset), corner = min(radius, r.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.midX, y: r.minY), radius: corner)
        path.closeSubpath()
        return path
    }
}
