import CoreGraphics
import Foundation

/// The layout of one screen with the areas that lie beyond its left and right edges: one strip, as wide as the screen
/// plus all the areas. There may be as many areas on a side as the user adds, one after the other. Value type.
public struct StripLayout: Equatable {
    public enum Part: Equatable { case leading, screen, trailing }

    /// The areas beyond the left edge, the one next to the screen first.
    public var leading: [Overflow]
    public var root: LayoutNode
    /// The areas beyond the right edge, the one next to the screen first.
    public var trailing: [Overflow]

    public init(leading: [Overflow] = [], root: LayoutNode, trailing: [Overflow] = []) {
        self.leading = leading
        self.root = root
        self.trailing = trailing
    }

    /// The widths of all the areas on a side, in screen widths.
    public var leadingWidth: Double { leading.reduce(0) { $0 + $1.width } }
    public var trailingWidth: Double { trailing.reduce(0) { $0 + $1.width } }

    /// Everything, in screen widths.
    public var totalWidth: Double { 1 + leadingWidth + trailingWidth }

    /// The offsets (in screen widths, to the right of the screen's own place) where a view of one screen width rests at a screen: the
    /// screen's own layout and the far edge of each area, on both sides, from the left to the right. What the layout editor goes by.
    public var areaRests: [Double] {
        var offsets: Set<Double> = [0]
        var reached = 0.0
        for area in trailing { reached += area.width; offsets.insert(reached) }
        reached = 0
        for area in leading { reached += area.width; offsets.insert(-reached) }
        return offsets.sorted()
    }

    /// Every place across the strip where a zone ends and the next begins, or the strip ends, in screen widths from the screen's left
    /// edge: the vertical lines between zones, on the screen and in all the areas.
    public var zoneEdges: [Double] {
        var edges: Set<Double> = []
        func add(_ node: LayoutNode, from start: Double, width: Double) {
            // Laid out in thousandths of a screen, so that the arithmetic of the splits stays far from rounding.
            for zone in node.zones(in: CGRect(x: start * 1000, y: 0, width: width * 1000, height: 1000)) {
                edges.insert((zone.rect.minX * 1000).rounded() / 1_000_000)
                edges.insert((zone.rect.maxX * 1000).rounded() / 1_000_000)
            }
        }
        var reached = 0.0
        for area in leading { reached += area.width; add(area.root, from: -reached, width: area.width) }
        add(root, from: 0, width: 1)
        reached = 1
        for area in trailing { add(area.root, from: reached, width: area.width); reached += area.width }
        return edges.sorted()
    }

    /// The offsets where scrolling comes to rest: whenever a line between zones (or an end of the strip) is at the left or the right
    /// edge of the screen, within how far the strip goes, from the left to the right. The screen's own layout is one of them.
    public var rests: [Double] {
        let range = -leadingWidth - 1e-9 ... trailingWidth + 1e-9
        var offsets: Set<Double> = [0]
        for edge in zoneEdges {
            for offset in [edge, edge - 1] where range.contains(offset) { offsets.insert((offset * 1_000_000).rounded() / 1_000_000) }
        }
        return offsets.sorted()
    }

    /// The area that a view resting at `offset` is about: the one whose far edge it stands at; nil for the screen's own layout.
    public func area(at offset: Double) -> Overflow? {
        var reached = 0.0
        for area in trailing {
            reached += area.width
            if abs(reached - offset) < 1e-9 { return area }
        }
        reached = 0
        for area in leading {
            reached += area.width
            if abs(-reached - offset) < 1e-9 { return area }
        }
        return nil
    }

    /// Every zone in order across the strip: the outermost area on the left first, the outermost on the right last.
    public var zoneIDs: [UUID] { leadingZoneIDs + root.leafIDs + trailingZoneIDs }

    private var leadingZoneIDs: [UUID] { leading.reversed().flatMap { $0.root.leafIDs } }
    private var trailingZoneIDs: [UUID] { trailing.flatMap { $0.root.leafIDs } }

    /// This screen layout with the areas beyond the edges of `other` (for an editor that did not show them).
    public func keepingAreas(of other: StripLayout) -> StripLayout {
        StripLayout(leading: other.leading, root: root, trailing: other.trailing)
    }

    public func part(of zone: UUID) -> Part? {
        if root.leafIDs.contains(zone) { return .screen }
        if leadingZoneIDs.contains(zone) { return .leading }
        if trailingZoneIDs.contains(zone) { return .trailing }
        return nil
    }

    /// Where a zone is counted from, for naming it: the screen's zones from 1 in tree order, the zones beyond an edge from 1
    /// outwards, across all the areas on that side (so the nearest to the screen is 1 on either side).
    public func position(of zone: UUID) -> (part: Part, number: Int)? {
        if let i = root.leafIDs.firstIndex(of: zone) { return (.screen, i + 1) }
        let left = leadingZoneIDs
        if let i = left.firstIndex(of: zone) { return (.leading, left.count - i) }
        if let i = trailingZoneIDs.firstIndex(of: zone) { return (.trailing, i + 1) }
        return nil
    }

    // MARK: One tree

    /// The whole strip as one split tree, so the editor can treat it like any layout: the lines between the screen and
    /// the areas, and between the areas, are ordinary splits (with the areas' ids). Each area wraps what lies inside it.
    public var composite: LayoutNode {
        var inner = root
        var width = 1.0
        for area in trailing {
            inner = .split(id: area.id, sideBySide: true, ratio: width / (width + area.width), first: inner, second: area.root)
            width += area.width
        }
        for area in leading {
            inner = .split(id: area.id, sideBySide: true, ratio: area.width / (area.width + width), first: area.root, second: inner)
            width += area.width
        }
        return inner
    }

    /// The reverse of `composite`: finds the areas by the ids of their lines (next to the screen first). An area whose line is
    /// not in the tree is not there, and neither are those beyond it.
    public init(composite: LayoutNode, leadingIDs: [UUID], trailingIDs: [UUID]) {
        var node = composite
        // Outermost first: that is how the composite nests them.
        var leadingLines: [(id: UUID, ratio: Double, root: LayoutNode)] = []
        for id in leadingIDs.reversed() {
            guard case .split(let splitID, true, let ratio, let first, let second) = node, splitID == id else { break }
            leadingLines.append((id, ratio, first))
            node = second
        }
        var trailingLines: [(id: UUID, ratio: Double, root: LayoutNode)] = []
        for id in trailingIDs.reversed() {
            guard case .split(let splitID, true, let ratio, let first, let second) = node, splitID == id else { break }
            trailingLines.append((id, ratio, second))
            node = first
        }
        self.root = node
        // The widths from the inside out: a line's ratio is relative to everything inside it.
        var width = 1.0
        var trailing: [Overflow] = []
        for line in trailingLines.reversed() where line.ratio > 0 {
            let area = (1 - line.ratio) / line.ratio * width
            trailing.append(Overflow(id: line.id, width: area, root: line.root))
            width += area
        }
        var leading: [Overflow] = []
        for line in leadingLines.reversed() where line.ratio < 1 {
            let area = line.ratio * width / (1 - line.ratio)
            leading.append(Overflow(id: line.id, width: area, root: line.root))
            width += area
        }
        self.trailing = trailing
        self.leading = leading
    }

    // MARK: Edits

    /// Merges two zones of the same part and area (a zone cannot reach across the edge of the screen or of an area).
    public func merging(_ a: UUID, _ b: UUID) -> StripLayout? {
        var result = self
        if root.leafIDs.contains(a), root.leafIDs.contains(b) {
            guard let merged = root.merging(a, b, in: Self.area(1)) else { return nil }
            result.root = merged
            return result
        }
        for i in leading.indices where leading[i].root.leafIDs.contains(a) && leading[i].root.leafIDs.contains(b) {
            guard let merged = leading[i].root.merging(a, b, in: Self.area(leading[i].width)) else { return nil }
            result.leading[i].root = merged
            return result
        }
        for i in trailing.indices where trailing[i].root.leafIDs.contains(a) && trailing[i].root.leafIDs.contains(b) {
            guard let merged = trailing[i].root.merging(a, b, in: Self.area(trailing[i].width)) else { return nil }
            result.trailing[i].root = merged
            return result
        }
        return nil
    }

    private static func area(_ width: Double) -> CGRect { CGRect(x: 0, y: 0, width: width * 1000, height: 1000) }
}
