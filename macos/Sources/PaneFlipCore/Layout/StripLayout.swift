import CoreGraphics
import Foundation

/// The layout of one screen with the areas that lie beyond its left and right edges: one strip, as wide as the screen
/// plus both overflows. Value type.
public struct StripLayout: Equatable {
    public enum Part: Equatable { case leading, screen, trailing }

    public var leading: Overflow?
    public var root: LayoutNode
    public var trailing: Overflow?

    public init(leading: Overflow? = nil, root: LayoutNode, trailing: Overflow? = nil) {
        self.leading = leading
        self.root = root
        self.trailing = trailing
    }

    /// Everything, in screen widths.
    public var totalWidth: Double { 1 + (leading?.width ?? 0) + (trailing?.width ?? 0) }

    public var zoneIDs: [UUID] { (leading?.root.leafIDs ?? []) + root.leafIDs + (trailing?.root.leafIDs ?? []) }

    /// This screen layout with the areas beyond the edges of `other` (for an editor that did not show them).
    public func keepingAreas(of other: StripLayout) -> StripLayout {
        StripLayout(leading: other.leading, root: root, trailing: other.trailing)
    }

    public func part(of zone: UUID) -> Part? {
        if root.leafIDs.contains(zone) { return .screen }
        if leading?.root.leafIDs.contains(zone) == true { return .leading }
        if trailing?.root.leafIDs.contains(zone) == true { return .trailing }
        return nil
    }

    /// Where a zone is counted from, for naming it: the screen's zones from 1 in tree order, the zones beyond an edge from 1
    /// outwards (so the nearest to the screen is 1 on either side).
    public func position(of zone: UUID) -> (part: Part, number: Int)? {
        if let i = root.leafIDs.firstIndex(of: zone) { return (.screen, i + 1) }
        if let ids = leading?.root.leafIDs, let i = ids.firstIndex(of: zone) { return (.leading, ids.count - i) }
        if let i = trailing?.root.leafIDs.firstIndex(of: zone) { return (.trailing, i + 1) }
        return nil
    }

    // MARK: One tree

    /// The whole strip as one split tree, so the editor can treat it like any layout: the lines between the screen and
    /// the overflows are ordinary splits (with the overflows' ids).
    public var composite: LayoutNode {
        var inner = root
        if let t = trailing {
            inner = .split(id: t.id, sideBySide: true, ratio: 1 / (1 + t.width), first: root, second: t.root)
        }
        guard let l = leading else { return inner }
        let rest = 1 + (trailing?.width ?? 0)
        return .split(id: l.id, sideBySide: true, ratio: l.width / (l.width + rest), first: l.root, second: inner)
    }

    /// The reverse of `composite`: finds the overflows by the ids of their lines. A tree without such a line has no
    /// overflow on that side.
    public init(composite: LayoutNode, leadingID: UUID?, trailingID: UUID?) {
        var node = composite
        var leadingRatio: Double?, leadingRoot: LayoutNode?
        if let id = leadingID, case .split(let splitID, true, let r, let first, let second) = node, splitID == id {
            leadingRatio = r
            leadingRoot = first
            node = second
        }
        var trailingWidth: Double?, trailingRoot: LayoutNode?
        if let id = trailingID, case .split(let splitID, true, let r, let first, let second) = node, splitID == id, r > 0 {
            trailingWidth = (1 - r) / r
            trailingRoot = second
            node = first
        }
        self.root = node
        self.trailing = trailingID.flatMap { id in trailingRoot.map { Overflow(id: id, width: trailingWidth ?? 0, root: $0) } }
        if let id = leadingID, let r = leadingRatio, let leadingRoot, r < 1 {
            self.leading = Overflow(id: id, width: r * (1 + (trailingWidth ?? 0)) / (1 - r), root: leadingRoot)
        } else {
            self.leading = nil
        }
    }

    // MARK: Edits

    /// Merges two zones of the same part (a zone cannot reach across the edge of the screen).
    public func merging(_ a: UUID, _ b: UUID) -> StripLayout? {
        guard let part = part(of: a), part == self.part(of: b) else { return nil }
        var result = self
        switch part {
        case .screen: guard let merged = root.merging(a, b, in: Self.area(1)) else { return nil }; result.root = merged
        case .leading: guard let l = leading, let merged = l.root.merging(a, b, in: Self.area(l.width)) else { return nil }; result.leading?.root = merged
        case .trailing: guard let t = trailing, let merged = t.root.merging(a, b, in: Self.area(t.width)) else { return nil }; result.trailing?.root = merged
        }
        return result
    }

    private static func area(_ width: Double) -> CGRect { CGRect(x: 0, y: 0, width: width * 1000, height: 1000) }
}
