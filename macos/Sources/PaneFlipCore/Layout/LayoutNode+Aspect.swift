import CoreGraphics
import Foundation

/// Zones that keep their width-to-height ratio while the lines of a layout move. The zones are measured as they are drawn (`Laid`: with the gap and the margin), the lines
/// are moved on the plain tree.
extension LayoutNode {
    public typealias Laid = (LayoutNode) -> [(id: UUID, rect: CGRect)]

    private static let tolerance = 0.001

    private func isOff(_ zone: UUID, _ aspect: Double, laid: Laid) -> Bool {
        guard let r = laid(self).first(where: { $0.id == zone })?.rect, r.height > 0 else { return true }
        return abs(r.width / r.height / aspect - 1) > Self.tolerance
    }

    /// Moves a line on the far side of a zone (else on its near side) so that the zone is `delta` points longer along that line's axis.
    /// `heightLines`: the horizontal lines, which set the zone's height, else the vertical ones, which set its width.
    private func stretching(_ zone: UUID, by delta: CGFloat, heightLines: Bool, avoiding line: UUID?, in rect: CGRect, least: CGFloat) -> LayoutNode? {
        guard let plain = zones(in: rect).first(where: { $0.id == zone })?.rect else { return nil }
        let edges = dividers(in: rect).filter { $0.id != line && $0.sideBySide != heightLines }
        let far = heightLines ? plain.maxY : plain.maxX, near = heightLines ? plain.minY : plain.minX
        let spanLow = heightLines ? plain.minX : plain.minY, spanHigh = heightLines ? plain.maxX : plain.maxY
        func borders(_ d: SplitDivider, at edge: CGFloat) -> Bool {
            let low = heightLines ? d.parent.minX : d.parent.minY, high = heightLines ? d.parent.maxX : d.parent.maxY
            return abs(d.position - edge) < 0.5 && low <= spanLow + 0.5 && high >= spanHigh - 0.5
        }
        // The far edge first: the zone grows away from the top and the left.
        let (d, sign): (SplitDivider, CGFloat)
        if let found = edges.first(where: { borders($0, at: far) }) { (d, sign) = (found, 1) }
        else if let found = edges.first(where: { borders($0, at: near) }) { (d, sign) = (found, -1) }
        else { return nil }
        let ratio = Double((d.position + sign * delta - (d.sideBySide ? d.parent.minX : d.parent.minY)) / d.extent)
        return movingLine(d.id, to: ratio, in: rect, least: least)?.node
    }

    /// The tree with every zone of `aspects` at its ratio, moving for each the lines that lie across its height first (`heightFirst`) or across its width; nil if a zone cannot.
    private func fitted(_ aspects: [UUID: Double], heightFirst: Bool, avoiding line: UUID?, in rect: CGRect, least: CGFloat, laid: Laid) -> LayoutNode? {
        var node = self
        let order = leafIDs.filter { aspects[$0] != nil }
        for _ in 0 ... order.count {
            guard let zone = order.first(where: { node.isOff($0, aspects[$0]!, laid: laid) }), let aspect = aspects[zone] else { return node }
            guard let r = laid(node).first(where: { $0.id == zone })?.rect else { return nil }
            let heightDelta = r.width / CGFloat(aspect) - r.height, widthDelta = r.height * CGFloat(aspect) - r.width
            guard let next = (heightFirst ? [true, false] : [false, true]).lazy.compactMap({ tall in
                node.stretching(zone, by: tall ? heightDelta : widthDelta, heightLines: tall, avoiding: line, in: rect, least: least)
            }).first else { return nil }
            node = next
        }
        return order.allSatisfy { !node.isOff($0, aspects[$0]!, laid: laid) } ? node : nil
    }

    /// `zone` brought to `aspect` with the other zones of `aspects` kept at theirs; nil if the lines cannot give it that.
    public func settingAspect(of zone: UUID, to aspect: ZoneAspect, among aspects: [UUID: ZoneAspect], in rect: CGRect, least: CGFloat, laid: Laid) -> LayoutNode? {
        var ratios = aspects.mapValues(\.value)
        ratios[zone] = aspect.value
        return fitted(ratios, heightFirst: true, avoiding: nil, in: rect, least: least, laid: laid)
    }

    /// `movingLine` with the zones of `aspects` kept at their ratios: the lines across the other axis of each move with the line, and the line stops where they cannot.
    public func movingLine(_ splitID: UUID, to ratio: Double, in rect: CGRect, least: CGFloat, aspects: [UUID: ZoneAspect], laid: Laid) -> (node: LayoutNode, ratio: Double)? {
        guard !aspects.isEmpty else { return movingLine(splitID, to: ratio, in: rect, least: least) }
        guard let current = self.ratio(ofSplit: splitID), let side = dividers(in: rect).first(where: { $0.id == splitID })?.sideBySide else { return nil }
        let ratios = aspects.mapValues(\.value)
        func attempt(_ t: Double) -> LayoutNode? {
            rebuiltLine(splitID, to: t, in: rect, least: least)?.fitted(ratios, heightFirst: side, avoiding: splitID, in: rect, least: least, laid: laid)
        }
        if let node = attempt(ratio) { return (node, ratio) }
        var good = current, bad = ratio
        for _ in 0 ..< 30 {
            let middle = (good + bad) / 2
            if attempt(middle) != nil { good = middle } else { bad = middle }
        }
        return attempt(good).map { ($0, good) }
    }

    /// The tree with only the line `splitID` moved to exactly `ratio`, or nil if a zone would get shorter than `least`.
    private func rebuiltLine(_ splitID: UUID, to ratio: Double, in rect: CGRect, least: CGFloat) -> LayoutNode? {
        movingLine(splitID, to: ratio, in: rect, least: least).flatMap { abs($0.ratio - ratio) < 1e-9 ? $0.node : nil }
    }
}
