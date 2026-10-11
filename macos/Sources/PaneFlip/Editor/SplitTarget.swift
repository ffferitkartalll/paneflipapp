import CoreGraphics

/// Where a click would split a zone, and whether that split is allowed.
struct SplitTarget {
    let zone: ZoneRect
    let sideBySide: Bool
    let ratio: Double
    let valid: Bool
    let snapped: Bool

    var line: (CGPoint, CGPoint) {
        let r = zone.rect
        if sideBySide {
            let x = r.minX + r.width * ratio
            return (CGPoint(x: x, y: r.minY), CGPoint(x: x, y: r.maxY))
        }
        let y = r.minY + r.height * ratio
        return (CGPoint(x: r.minX, y: y), CGPoint(x: r.maxX, y: y))
    }
}
