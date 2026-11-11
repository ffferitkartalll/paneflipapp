import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

/// Editing state for one layout and the areas beyond its screen's edges. Nothing reaches the app until `apply()`.
@Observable
final class EditorModel {
    private(set) var strip: StripLayout
    /// False when the areas beyond the screen are switched off: they are neither shown nor added.
    let allowsOverflow: Bool
    /// The gap between the zones and the margin round the layout, in points, as the desktop lays the zones out.
    var gap: CGFloat
    var margin: CGFloat
    /// The least a zone may be, in points: the editor does not split or resize a zone below it.
    var minZoneSize: Double
    var hover: CGPoint?
    var shift = false
    /// Zone being dragged onto a neighbour to merge, and where the pointer is.
    var mergeSource: UUID?
    var dragPoint: CGPoint?
    /// Where the view rests, in screen widths to the right of the screen's own place: the editor shows one screen's width of the
    /// strip from here, and scrolling moves it from one rest to the next.
    private(set) var offset = 0.0
    @ObservationIgnored private var paged = PagedScroll()

    /// What was before each change, newest last, and what undoing took away (until the next change).
    private(set) var past: [Snapshot] = []
    private(set) var future: [Snapshot] = []
    /// The line being dragged: the moves of one drag are one change.
    @ObservationIgnored private var resizing: UUID?

    /// The zone that takes the apps whose zone is gone; nil while the layout keeps the first one.
    private(set) var defaultZone: UUID?

    /// The width-to-height ratio each zone keeps while the lines move; a zone without one is free.
    private(set) var aspects: [UUID: ZoneAspect]

    @ObservationIgnored private let onApply: (EditorModel) -> Void
    @ObservationIgnored private let onClose: () -> Void

    init(strip: StripLayout, allowsOverflow: Bool = true, gap: CGFloat = 0, margin: CGFloat = 0, minZoneSize: Double = AppSettings.minZoneSizeRange.lowerBound,
         defaultZone: UUID? = nil, aspects: [UUID: ZoneAspect] = [:], onApply: @escaping (EditorModel) -> Void, onClose: @escaping () -> Void) {
        self.strip = strip
        self.allowsOverflow = allowsOverflow
        self.gap = gap
        self.margin = margin
        self.minZoneSize = minZoneSize
        self.defaultZone = defaultZone
        self.aspects = aspects
        self.onApply = onApply
        self.onClose = onClose
    }

    /// The screen and both overflows as one tree: what the editor draws and the lines it lets the user drag.
    var root: LayoutNode { strip.composite }

    /// The zones and the lines to draw in `rect` (the whole strip; `screen` is the part of it that is the screen). Every screen of the strip, the screen's own and each one beyond
    /// its edges, stands as the desktop lays it: with the gap between its zones and the margin round it, so that a line is where it is on the desktop.
    func laid(in rect: CGRect, screen: CGRect) -> (zones: [(id: UUID, rect: CGRect)], dividers: [SplitDivider]) { laid(strip, in: rect, screen: screen) }

    private func laid(_ strip: StripLayout, in rect: CGRect, screen: CGRect) -> (zones: [(id: UUID, rect: CGRect)], dividers: [SplitDivider]) {
        let root = strip.composite
        let zones = root.zones(in: rect), dividers = root.dividers(in: rect)
        guard gap > 0 || margin > 0 else { return (zones, dividers) }
        var ownZones: [UUID: CGRect] = [:], ownLines: [UUID: SplitDivider] = [:]
        for part in Self.screens(of: strip, screen: screen) {
            let reach = lineReach(in: part.rect)
            for zone in part.root.zones(in: Self.inset(part.rect, by: margin), gap: gap) { ownZones[zone.id] = zone.rect }
            for line in part.root.dividers(in: reach.inner) { ownLines[line.id] = line.reaching(reach.inner, to: reach.outer) }
        }
        return (zones.map { zone in ownZones[zone.id].map { (id: zone.id, rect: $0) } ?? zone }, dividers.map { ownLines[$0.id] ?? $0 })
    }

    /// The screens of a strip in the picture, each with its layout: the screen's own at `screen`, those beyond its edges beside it, one after the other.
    private static func screens(of strip: StripLayout, screen: CGRect) -> [(root: LayoutNode, rect: CGRect)] {
        var parts = [(root: strip.root, rect: screen)]
        var x = screen.maxX
        for area in strip.trailing {
            let width = CGFloat(area.width) * screen.width
            parts.append((area.root, CGRect(x: x, y: screen.minY, width: width, height: screen.height)))
            x += width
        }
        x = screen.minX
        for area in strip.leading {
            let width = CGFloat(area.width) * screen.width
            x -= width
            parts.append((area.root, CGRect(x: x, y: screen.minY, width: width, height: screen.height)))
        }
        return parts
    }

    private static func inset(_ rect: CGRect, by margin: CGFloat) -> CGRect {
        CGRect(x: rect.minX + margin, y: rect.minY + margin, width: max(rect.width - 2 * margin, 0), height: max(rect.height - 2 * margin, 0))
    }

    /// The area the lines of a screen of the strip are laid in (`inner`) and the screen they are drawn out to (`outer`, `rect`).
    private func lineReach(in rect: CGRect) -> (inner: CGRect, outer: CGRect) {
        (LayoutNode.lineArea(Self.inset(rect, by: margin), gap: gap), rect)
    }

    /// `lineReach` of the screen of the strip that `zone` is in: the same for a line there is and for one a click would make.
    func lineReach(of zone: UUID, screen: CGRect) -> (inner: CGRect, outer: CGRect)? {
        Self.screens(of: strip, screen: screen).first { $0.root.leafIDs.contains(zone) }.map { lineReach(in: $0.rect) }
    }

    func apply() {
        onApply(self)
        onClose()
    }

    func close() { onClose() }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Call before a change: what is now becomes the thing undo goes back to.
    @ObservationIgnored private var gridBase: Snapshot?

    private func checkpoint() {
        past.append(Snapshot(strip: strip, offset: offset, defaultZone: defaultZone, aspects: aspects))
        future = []
        resizing = nil
    }

    func undo() {
        guard let before = past.popLast() else { return }
        future.append(Snapshot(strip: strip, offset: offset, defaultZone: defaultZone, aspects: aspects))
        strip = before.strip
        offset = before.offset
        defaultZone = before.defaultZone
        aspects = before.aspects
        resizing = nil
    }

    func redo() {
        guard let after = future.popLast() else { return }
        past.append(Snapshot(strip: strip, offset: offset, defaultZone: defaultZone, aspects: aspects))
        strip = after.strip
        offset = after.offset
        defaultZone = after.defaultZone
        aspects = after.aspects
        resizing = nil
    }

    /// The screen's zone that receives apps whose zone is gone: the chosen one while it still exists, else the first.
    var effectiveDefaultZone: UUID? {
        let zones = strip.root.leafIDs
        return defaultZone.flatMap { zones.contains($0) ? $0 : nil } ?? zones.first
    }

    func setDefaultZone(_ zone: UUID) {
        guard zone != effectiveDefaultZone, strip.root.leafIDs.contains(zone) else { return }
        checkpoint()
        defaultZone = zone
    }

    /// The screen in view goes back to one zone (the first it had); the other screens stay as they are.
    func reset() {
        checkpoint()
        replaceEditedRoot(.leaf(strip.root(at: offset).leafIDs[0]))
    }

    /// The screen in view takes `node` as its layout; the zones it had lose their ratios.
    private func replaceEditedRoot(_ node: LayoutNode) {
        for id in strip.root(at: offset).leafIDs { aspects[id] = nil }
        strip.setRoot(node, at: offset)
    }

    /// The screen in view (the screen itself or one beyond its edge) takes the shape of a preset; its zones keep the identities of the zones it had, in order.
    func useShape(_ preset: LayoutPreset) {
        checkpoint()
        replaceEditedRoot(preset.root.reusing(strip.root(at: offset).leafIDs))
    }

    /// Shows a grid on the screen in view while its sliders move; `applyGrid` keeps it as one change, `cancelGrid` puts back what was there.
    func previewGrid(rows: Int, columns: Int) {
        let base = gridBase ?? Snapshot(strip: strip, offset: offset, defaultZone: defaultZone, aspects: aspects)
        gridBase = base
        strip = base.strip
        aspects = base.aspects
        replaceEditedRoot(LayoutPreset.custom(rows: rows, columns: columns).root.reusing(strip.root(at: offset).leafIDs))
    }

    func applyGrid() {
        guard let base = gridBase else { return }
        past.append(base)
        future = []
        gridBase = nil
    }

    func cancelGrid() {
        guard let base = gridBase else { return }
        strip = base.strip; offset = base.offset; defaultZone = base.defaultZone; aspects = base.aspects
        gridBase = nil
    }

    /// The area the view is about (nil on the screen's own layout), which the user may remove.
    var editedArea: Overflow? { strip.area(at: offset) }
    /// The plus buttons show where the view is at the outermost screen on that side: another one comes after it.
    var canAddLeading: Bool { allowsOverflow && abs(offset - (strip.areaRests.first ?? 0)) < 1e-9 }
    var canAddTrailing: Bool { allowsOverflow && abs(offset - (strip.areaRests.last ?? 0)) < 1e-9 }

    /// Another screen, as wide as the screen, beyond the left (right) edge, outside the ones there are; the view goes to it.
    func addLeading() {
        checkpoint()
        strip.leading.append(Overflow(width: 1))
        offset = -strip.leadingWidth
    }

    func addTrailing() {
        checkpoint()
        strip.trailing.append(Overflow(width: 1))
        offset = strip.trailingWidth
    }

    func removeEditedArea() { if let area = editedArea { collapse(area.id) } }

    /// The view moves `steps` screens along (negative: to the left), as far as there are.
    func step(_ steps: Int) {
        let rests = strip.areaRests
        guard steps != 0 else { return }
        offset = rests[min(max(strip.nearestAreaRestIndex(to: offset) + steps, 0), rests.count - 1)]
    }

    /// Two fingers moved sideways, or lifted.
    func scrolled(horizontal: CGFloat, finished: Bool) { step(paged.add(horizontal: horizontal, finished: finished)) }

    /// A notch of the mouse wheel.
    func wheel(_ delta: CGFloat) { step(PagedScroll.notch(delta)) }

    /// After an area went: the view rests at the nearest of the rests there are.
    private func settle() {
        offset = strip.areaRests[strip.nearestAreaRestIndex(to: offset)]
    }

    /// A zone's size in points, worked out from its share of the view; empty while the view has no size yet.
    static func size(of rect: CGRect, in view: CGSize, area: CGSize) -> String {
        guard view.width > 0, view.height > 0 else { return "" }
        return "\(Int((rect.width / view.width * area.width).rounded())) × \(Int((rect.height / view.height * area.height).rounded()))"
    }

    /// Whether a line of the tree is the edge of an area (the editor does not let the user drag those: a screen has the width of the screen).
    func isAreaLine(_ line: UUID) -> Bool { strip.leading.contains { $0.id == line } || strip.trailing.contains { $0.id == line } }

    func split(_ zone: UUID, sideBySide: Bool, ratio: Double) {
        checkpoint()
        aspects[zone] = nil   // halved, it is no longer at its ratio
        edit { $0.splitting(zone, sideBySide: sideBySide, ratio: ratio) }
    }

    /// Moves a line in the strip as drawn in `rect`; no other line moves, and the line stops where it would pass the next one (zones of at least `least` points are left).
    /// The moves of one drag (until `endResize`) are one change to undo.
    /// The zones with a ratio keep it: the lines across them move with the line.
    func setRatio(_ line: UUID, _ ratio: Double, in rect: CGRect, screen: CGRect, least: CGFloat) {
        if resizing != line {
            checkpoint()
            resizing = line
        }
        edit { $0.movingLine(line, to: ratio, in: rect, least: least, aspects: aspects, laid: laidZones(in: rect, screen: screen))?.node ?? $0 }
    }

    private func laidZones(in rect: CGRect, screen: CGRect) -> LayoutNode.Laid {
        { [self] node in laid(StripLayout(composite: node, leadingIDs: strip.leading.map(\.id), trailingIDs: strip.trailing.map(\.id)), in: rect, screen: screen).zones }
    }

    /// The zone brought to `aspect` by moving its lines, or nil if they cannot give it that (a zone along both edges of the screen has no line to move).
    private func fitting(_ aspect: ZoneAspect, zone: UUID, in rect: CGRect, screen: CGRect, least: CGFloat) -> LayoutNode? {
        strip.composite.settingAspect(of: zone, to: aspect, among: aspects, in: rect, least: least, laid: laidZones(in: rect, screen: screen))
    }

    func canSetAspect(_ aspect: ZoneAspect, of zone: UUID, in rect: CGRect, screen: CGRect, least: CGFloat) -> Bool {
        fitting(aspect, zone: zone, in: rect, screen: screen, least: least) != nil
    }

    /// Keeps `zone` at `aspect` from now on (nil: free), moving its lines to it.
    func setAspect(_ aspect: ZoneAspect?, of zone: UUID, in rect: CGRect, screen: CGRect, least: CGFloat) {
        guard let aspect else {
            guard aspects[zone] != nil else { return }
            checkpoint()
            aspects[zone] = nil
            return
        }
        guard let node = fitting(aspect, zone: zone, in: rect, screen: screen, least: least) else { return }
        checkpoint()
        aspects[zone] = aspect
        edit { _ in node }
    }

    func endResize() { resizing = nil }

    /// Removing the line in front of an area removes the area (the ones beyond it move in); any other line joins its two sides.
    func collapse(_ line: UUID) {
        checkpoint()
        if let i = strip.leading.firstIndex(where: { $0.id == line }) { strip.leading.remove(at: i) }
        else if let i = strip.trailing.firstIndex(where: { $0.id == line }) { strip.trailing.remove(at: i) }
        else {
            // The zones of its two sides become one.
            if let sides = strip.composite.sides(ofSplit: line) { (sides.first.leafIDs + sides.second.leafIDs).forEach { aspects[$0] = nil } }
            edit { $0.collapsing(line) }
        }
        settle()
    }

    /// What merging two zones would give, or nil when it cannot be done.
    func merged(_ a: UUID, _ b: UUID) -> StripLayout? { strip.merging(a, b) }

    func merge(_ a: UUID, _ b: UUID) {
        guard let result = merged(a, b) else { return }
        checkpoint()
        aspects[a] = nil
        aspects[b] = nil
        strip = result
    }

    private func edit(_ change: (LayoutNode) -> LayoutNode) {
        strip = StripLayout(composite: change(strip.composite), leadingIDs: strip.leading.map(\.id), trailingIDs: strip.trailing.map(\.id))
    }
}
