import CoreGraphics
import Foundation

/// A screen's zone layout as a binary split tree. Leaves are zones. Value type: every edit returns a new tree.
public indirect enum LayoutNode: Codable, Equatable {
    case leaf(UUID)
    case split(id: UUID, sideBySide: Bool, ratio: Double, first: LayoutNode, second: LayoutNode)

    /// Zone identifiers in tree order (left/top first).
    public var leafIDs: [UUID] {
        switch self {
        case .leaf(let id): return [id]
        case .split(_, _, _, let a, let b): return a.leafIDs + b.leafIDs
        }
    }

    /// The same tree with identities of its own; `ids` collects which new zone stands for which old one.
    func renewed(_ ids: inout [UUID: UUID]) -> LayoutNode {
        switch self {
        case .leaf(let id):
            let new = UUID()
            ids[id] = new
            return .leaf(new)
        case .split(_, let side, let ratio, let a, let b):
            let first = a.renewed(&ids)
            return .split(id: UUID(), sideBySide: side, ratio: ratio, first: first, second: b.renewed(&ids))
        }
    }

    static func childRects(_ rect: CGRect, sideBySide: Bool, ratio: Double) -> (CGRect, CGRect) {
        if sideBySide {
            let w = rect.width * ratio
            return (CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height),
                    CGRect(x: rect.minX + w, y: rect.minY, width: rect.width - w, height: rect.height))
        }
        let h = rect.height * ratio
        return (CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h),
                CGRect(x: rect.minX, y: rect.minY + h, width: rect.width, height: rect.height - h))
    }

    /// Splits a top-left-origin rectangle into zones. `gap` applies between zones only, never at the outer edges.
    public func zones(in rect: CGRect, gap: CGFloat = 0) -> [(id: UUID, rect: CGRect)] {
        switch self {
        case .leaf(let id):
            return [(id, rect)]
        case .split(_, let side, let r, let a, let b):
            var (ra, rb) = Self.childRects(rect, sideBySide: side, ratio: r)
            let h = gap / 2
            if side { ra.size.width -= h; rb.origin.x += h; rb.size.width -= h }
            else { ra.size.height -= h; rb.origin.y += h; rb.size.height -= h }
            return a.zones(in: ra, gap: gap) + b.zones(in: rb, gap: gap)
        }
    }

    public func dividers(in rect: CGRect) -> [SplitDivider] {
        switch self {
        case .leaf:
            return []
        case .split(let id, let side, let r, let a, let b):
            let (ra, rb) = Self.childRects(rect, sideBySide: side, ratio: r)
            return [SplitDivider(id: id, sideBySide: side, parent: rect, ratio: r)]
                + a.dividers(in: ra) + b.dividers(in: rb)
        }
    }

    /// Splits a zone at `ratio`; the first half keeps the old zone's identity (and so its stack).
    public func splitting(_ leafID: UUID, sideBySide: Bool, ratio: Double) -> LayoutNode {
        switch self {
        case .leaf(let l):
            guard l == leafID else { return self }
            return .split(id: UUID(), sideBySide: sideBySide, ratio: ratio, first: .leaf(l), second: .leaf(UUID()))
        case .split(let id, let s, let r, let a, let b):
            return .split(id: id, sideBySide: s, ratio: r,
                          first: a.splitting(leafID, sideBySide: sideBySide, ratio: ratio),
                          second: b.splitting(leafID, sideBySide: sideBySide, ratio: ratio))
        }
    }

    /// Merges exactly two zones into one. The merged zone must form a rectangle and the remaining
    /// zones must still be describable by nested splits; the tree is rebuilt from the zone rectangles.
    public func merging(_ a: UUID, _ b: UUID, in area: CGRect) -> LayoutNode? {
        let zs = zones(in: area)
        guard let za = zs.first(where: { $0.id == a }), let zb = zs.first(where: { $0.id == b }) else { return nil }
        let union = za.rect.union(zb.rect)
        guard abs(union.width * union.height - (za.rect.width * za.rect.height + zb.rect.width * zb.rect.height)) < 1 else { return nil }
        var rects = zs.filter { $0.id != a && $0.id != b }
        rects.append((a, union))
        return Self.build(rects, in: area)
    }

    /// Rebuilds a split tree from a tiling of `area`; nil if no edge-to-edge cut exists at some level.
    static func build(_ rects: [(id: UUID, rect: CGRect)], in area: CGRect) -> LayoutNode? {
        if rects.count == 1 { return .leaf(rects[0].id) }
        let e: CGFloat = 0.5
        for sideBySide in [true, false] {
            let cuts = Set(rects.map { sideBySide ? ($0.rect.maxX * 2).rounded() / 2 : ($0.rect.maxY * 2).rounded() / 2 })
            for c in cuts.sorted() {
                let end = sideBySide ? area.maxX : area.maxY
                guard c > (sideBySide ? area.minX : area.minY) + e, c < end - e else { continue }
                let first = rects.filter { (sideBySide ? $0.rect.maxX : $0.rect.maxY) <= c + e }
                let second = rects.filter { (sideBySide ? $0.rect.minX : $0.rect.minY) >= c - e }
                guard first.count + second.count == rects.count, !first.isEmpty, !second.isEmpty else { continue }
                let ratio = Double((c - (sideBySide ? area.minX : area.minY)) / (sideBySide ? area.width : area.height))
                let (ra, rb) = childRects(area, sideBySide: sideBySide, ratio: ratio)
                if let f = build(first, in: ra), let s = build(second, in: rb) {
                    return .split(id: UUID(), sideBySide: sideBySide, ratio: ratio, first: f, second: s)
                }
            }
        }
        return nil
    }

    public func settingRatio(_ splitID: UUID, _ ratio: Double) -> LayoutNode {
        switch self {
        case .leaf: return self
        case .split(let id, let s, let r, let a, let b):
            return .split(id: id, sideBySide: s, ratio: id == splitID ? ratio : r,
                          first: a.settingRatio(splitID, ratio), second: b.settingRatio(splitID, ratio))
        }
    }

    /// Removes a split line: its two sides become one zone (the first side's first zone survives).
    public func collapsing(_ splitID: UUID) -> LayoutNode {
        switch self {
        case .leaf: return self
        case .split(let id, let s, let r, let a, let b):
            if id == splitID { return .leaf(a.leafIDs[0]) }
            return .split(id: id, sideBySide: s, ratio: r, first: a.collapsing(splitID), second: b.collapsing(splitID))
        }
    }
}
