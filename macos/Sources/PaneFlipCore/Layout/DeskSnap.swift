import CoreGraphics

/// Where a display dragged on the desk comes to rest: always flush against another display, and lined up with the edges and the middles of the displays
/// when it is near them.
public enum DeskSnap {
    /// The place (top-left corner) for `moving`, which was dropped at its current place, among the frames `others` it must not overlap. Within `threshold` of
    /// a line that its far edge, near edge or middle can share with an edge or a middle of another display, it takes that line.
    public static func origin(of moving: CGRect, among others: [CGRect], threshold: CGFloat) -> CGPoint {
        guard !others.isEmpty else { return moving.origin }
        let w = moving.width, h = moving.height
        let xTargets = others.flatMap { [$0.minX, $0.maxX - w, $0.midX - w / 2] }
        let yTargets = others.flatMap { [$0.minY, $0.maxY - h, $0.midY - h / 2] }
        var best: (point: CGPoint, cost: CGFloat)?
        func consider(_ point: CGPoint) {
            let frame = CGRect(origin: point, size: moving.size).insetBy(dx: 0.5, dy: 0.5)
            guard !others.contains(where: { frame.intersects($0) }) else { return }
            let cost = hypot(point.x - moving.minX, point.y - moving.minY)
            if best == nil || cost < best!.cost { best = (point, cost) }
        }
        for other in others {
            for x in [other.maxX, other.minX - w] {
                for y in lines(near: moving.minY, among: yTargets, within: (other.minY - h + 1)...(other.maxY - 1), threshold) { consider(CGPoint(x: x, y: y)) }
            }
            for y in [other.maxY, other.minY - h] {
                for x in lines(near: moving.minX, among: xTargets, within: (other.minX - w + 1)...(other.maxX - 1), threshold) { consider(CGPoint(x: x, y: y)) }
            }
        }
        return best?.point ?? moving.origin
    }

    /// The lines of `targets` within `threshold` of `value` (inside `range`); with none, `value` itself held inside `range`.
    private static func lines(near value: CGFloat, among targets: [CGFloat], within range: ClosedRange<CGFloat>, _ threshold: CGFloat) -> [CGFloat] {
        let near = targets.filter { abs($0 - value) <= threshold && range.contains($0) }
        return near.isEmpty ? [min(max(value, range.lowerBound), range.upperBound)] : near
    }
}
