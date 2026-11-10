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

    /// The same shape with its zones standing for `ids` in tree order (so those zones keep their stacks); zones beyond `ids` stay new.
    public func reusing(_ ids: [UUID]) -> LayoutNode {
        var rest = ids[...]
        func walk(_ node: LayoutNode) -> LayoutNode {
            switch node {
            case .leaf(let l): return .leaf(rest.popFirst() ?? l)
            case .split(let id, let s, let r, let a, let b):
                let first = walk(a)
                return .split(id: id, sideBySide: s, ratio: r, first: first, second: walk(b))
            }
        }
        return walk(self)
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

    /// The rectangle the lines of a layout are laid in when there is a `gap`: the area with half a gap more on every side, so that taking half a gap from each side of
    /// every zone leaves the zones at the edges of the area (no gap there) and makes zones of equal ratios equally large.
    public static func lineArea(_ area: CGRect, gap: CGFloat) -> CGRect { area.insetBy(dx: -gap / 2, dy: -gap / 2) }

    /// Splits a top-left-origin rectangle into zones. The lines lie where the ratios put them in `lineArea(rect, gap:)`, and half the gap is taken from every side of every zone:
    /// a gap lies between zones only, the zones at the edges of `rect` reach them, and a ratio is a share of the room with every gap counted in: a layout of a quarter, a
    /// half and a quarter of 5120 points with a gap of 80 gives zones of 1220, 2520 and 1220, three equal columns three of one size.
    public func zones(in rect: CGRect, gap: CGFloat = 0) -> [(id: UUID, rect: CGRect)] {
        let half = gap / 2
        return plainZones(in: Self.lineArea(rect, gap: gap)).map { id, r in (id, r.insetBy(dx: half, dy: half)) }
    }

    private func plainZones(in rect: CGRect) -> [(id: UUID, rect: CGRect)] {
        switch self {
        case .leaf(let id):
            return [(id, rect)]
        case .split(_, let side, let r, let a, let b):
            let (ra, rb) = Self.childRects(rect, sideBySide: side, ratio: r)
            return a.plainZones(in: ra) + b.plainZones(in: rb)
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

    /// The ratio of the split line `splitID`, if the tree has it.
    public func ratio(ofSplit splitID: UUID) -> Double? {
        switch self {
        case .leaf: return nil
        case .split(let id, _, let r, let a, let b): return id == splitID ? r : a.ratio(ofSplit: splitID) ?? b.ratio(ofSplit: splitID)
        }
    }

    /// Moves the line `splitID` to `ratio` in `rect`, and no other line moves: a line inside the zones beside it keeps its place (its ratio changes, as the zone it divides
    /// grows or shrinks). No zone along a line's axis gets shorter than `least`: the line stops where the next one would be passed. Returns the tree and the ratio the line has.
    public func movingLine(_ splitID: UUID, to ratio: Double, in rect: CGRect, least: CGFloat) -> (node: LayoutNode, ratio: Double)? {
        guard let current = self.ratio(ofSplit: splitID) else { return nil }
        if let node = rebuilt(old: rect, new: rect, target: splitID, ratio: ratio, least: least) { return (node, ratio) }
        // Stops where it still fits: the last ratio between where it is and where it is asked to go.
        var good = current, bad = ratio
        for _ in 0 ..< 30 {
            let middle = (good + bad) / 2
            if rebuilt(old: rect, new: rect, target: splitID, ratio: middle, least: least) != nil { good = middle } else { bad = middle }
        }
        return rebuilt(old: rect, new: rect, target: splitID, ratio: good, least: least).map { ($0, good) }
    }

    private func rebuilt(old: CGRect, new: CGRect, target: UUID, ratio: Double, least: CGFloat) -> LayoutNode? {
        switch self {
        case .leaf:
            return self
        case .split(let id, let side, let r, let a, let b):
            let (oldA, oldB) = Self.childRects(old, sideBySide: side, ratio: r)
            var newRatio = r
            if id == target {
                newRatio = ratio
            } else {
                let oldMin = side ? old.minX : old.minY, oldExtent = side ? old.width : old.height
                let newMin = side ? new.minX : new.minY, newExtent = side ? new.width : new.height
                if abs(oldMin - newMin) > 1e-9 || abs(oldExtent - newExtent) > 1e-9 {
                    newRatio = Double((oldMin + oldExtent * CGFloat(r) - newMin) / newExtent)
                }
            }
            let (newA, newB) = Self.childRects(new, sideBySide: side, ratio: newRatio)
            guard (side ? newA.size.width : newA.size.height) >= least, (side ? newB.size.width : newB.size.height) >= least,
                  let first = a.rebuilt(old: oldA, new: newA, target: target, ratio: ratio, least: least),
                  let second = b.rebuilt(old: oldB, new: newB, target: target, ratio: ratio, least: least) else { return nil }
            return .split(id: id, sideBySide: side, ratio: newRatio, first: first, second: second)
        }
    }

    /// The two sides of the split line `splitID`, if the tree has it.
    public func sides(ofSplit splitID: UUID) -> (first: LayoutNode, second: LayoutNode)? {
        switch self {
        case .leaf: return nil
        case .split(let id, _, _, let a, let b): return id == splitID ? (a, b) : a.sides(ofSplit: splitID) ?? b.sides(ofSplit: splitID)
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
                // The cut itself, not its rounding to a half point: a ratio taken from the rounded cut moves every other line a little.
                let cut = first.map { sideBySide ? $0.rect.maxX : $0.rect.maxY }.max() ?? c
                let ratio = Double((cut - (sideBySide ? area.minX : area.minY)) / (sideBySide ? area.width : area.height))
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
