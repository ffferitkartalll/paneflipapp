import CoreGraphics

/// Where a click would split a zone, and whether that split is allowed.
struct SplitTarget {
    let zone: ZoneRect
    let sideBySide: Bool
    let ratio: Double
    let valid: Bool
    let snapped: Bool

    /// The two zones the split would make: left and right, or above and below.
    var halves: (CGRect, CGRect) {
        let r = zone.rect
        if sideBySide {
            let x = r.minX + r.width * ratio
            return (CGRect(x: r.minX, y: r.minY, width: x - r.minX, height: r.height), CGRect(x: x, y: r.minY, width: r.maxX - x, height: r.height))
        }
        let y = r.minY + r.height * ratio
        return (CGRect(x: r.minX, y: r.minY, width: r.width, height: y - r.minY), CGRect(x: r.minX, y: y, width: r.width, height: r.maxY - y))
    }

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
