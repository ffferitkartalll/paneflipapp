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

    struct Snapshot {
        let strip: StripLayout
        let offset: Double
    }

    @ObservationIgnored private let onApply: (StripLayout) -> Void
    @ObservationIgnored private let onClose: () -> Void

    init(strip: StripLayout, allowsOverflow: Bool = true, onApply: @escaping (StripLayout) -> Void, onClose: @escaping () -> Void) {
        self.strip = strip
        self.allowsOverflow = allowsOverflow
        self.onApply = onApply
        self.onClose = onClose
    }

    /// The screen and both overflows as one tree: what the editor draws and the lines it lets the user drag.
    var root: LayoutNode { strip.composite }

    func apply() {
        onApply(strip)
        onClose()
    }

    func close() { onClose() }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Call before a change: what is now becomes the thing undo goes back to.
    private func checkpoint() {
        past.append(Snapshot(strip: strip, offset: offset))
        future = []
        resizing = nil
    }

    func undo() {
        guard let before = past.popLast() else { return }
        future.append(Snapshot(strip: strip, offset: offset))
        strip = before.strip
        offset = before.offset
        resizing = nil
    }

    func redo() {
        guard let after = future.popLast() else { return }
        past.append(Snapshot(strip: strip, offset: offset))
        strip = after.strip
        offset = after.offset
        resizing = nil
    }

    func reset() {
        checkpoint()
        strip = StripLayout(root: .leaf(strip.root.leafIDs[0]))
        offset = 0
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
        edit { $0.splitting(zone, sideBySide: sideBySide, ratio: ratio) }
    }

    /// Moves a line; the moves of one drag (until `endResize`) are one change to undo.
    func setRatio(_ line: UUID, _ ratio: Double) {
        if resizing != line {
            checkpoint()
            resizing = line
        }
        edit { $0.settingRatio(line, ratio) }
    }

    func endResize() { resizing = nil }

    /// Removing the line in front of an area removes the area (the ones beyond it move in); any other line joins its two sides.
    func collapse(_ line: UUID) {
        checkpoint()
        if let i = strip.leading.firstIndex(where: { $0.id == line }) { strip.leading.remove(at: i) }
        else if let i = strip.trailing.firstIndex(where: { $0.id == line }) { strip.trailing.remove(at: i) }
        else { edit { $0.collapsing(line) } }
        settle()
    }

    /// What merging two zones would give, or nil when it cannot be done.
    func merged(_ a: UUID, _ b: UUID) -> StripLayout? { strip.merging(a, b) }

    func merge(_ a: UUID, _ b: UUID) {
        guard let result = merged(a, b) else { return }
        checkpoint()
        strip = result
    }

    private func edit(_ change: (LayoutNode) -> LayoutNode) {
        strip = StripLayout(composite: change(strip.composite), leadingIDs: strip.leading.map(\.id), trailingIDs: strip.trailing.map(\.id))
    }
}
