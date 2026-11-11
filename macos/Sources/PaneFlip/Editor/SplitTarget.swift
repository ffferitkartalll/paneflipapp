import PaneFlipCore
import CoreGraphics

/// Where a click would split a zone, and whether that split is allowed.
struct SplitTarget {
    let zone: ZoneRect
    let sideBySide: Bool
    let ratio: Double
    let valid: Bool
    let snapped: Bool

    /// The gap the zone's layout leaves between zones: the ratio is of the zone with that gap added on every side (`LayoutNode.lineArea`), as the lines are laid.
    var gap: CGFloat = 0

    /// Where the line would stand on its axis.
    private var position: CGFloat {
        let plain = LayoutNode.lineArea(zone.rect, gap: gap)
        return sideBySide ? plain.minX + plain.width * ratio : plain.minY + plain.height * ratio
    }

    /// The two zones the split would make: left and right, or above and below, the gap between them.
    var halves: (CGRect, CGRect) {
        let r = zone.rect, p = position, half = gap / 2
        if sideBySide {
            return (CGRect(x: r.minX, y: r.minY, width: p - half - r.minX, height: r.height), CGRect(x: p + half, y: r.minY, width: r.maxX - p - half, height: r.height))
        }
        return (CGRect(x: r.minX, y: r.minY, width: r.width, height: p - half - r.minY), CGRect(x: r.minX, y: p + half, width: r.width, height: r.maxY - p - half))
    }

    /// Where the lines of the zone's layout end (`inner`, the area they are laid in) and how far they are drawn (`outer`, the screen), if the zone is of the screen's own layout.
    var reach: (inner: CGRect, outer: CGRect)?

    /// The line as it will be drawn once the zone is split: across the zone with its half gaps, and on to the screen's edge where the zone lies along it.
    var line: (CGPoint, CGPoint) {
        var d = SplitDivider(id: zone.id, sideBySide: sideBySide, parent: LayoutNode.lineArea(zone.rect, gap: gap), ratio: ratio)
        if let reach { d = d.reaching(reach.inner, to: reach.outer) }
        let r = d.parent, p = d.position
        return sideBySide ? (CGPoint(x: p, y: r.minY), CGPoint(x: p, y: r.maxY)) : (CGPoint(x: r.minX, y: p), CGPoint(x: r.maxX, y: p))
    }
}
