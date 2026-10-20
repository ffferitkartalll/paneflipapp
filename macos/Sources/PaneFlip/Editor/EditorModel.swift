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

    func reset() { strip = StripLayout(root: .leaf(strip.root.leafIDs[0])) }

    /// Another area beyond the left (right) edge, outside the ones there are.
    func addLeading() { strip.leading.append(Overflow()) }
    func addTrailing() { strip.trailing.append(Overflow()) }

    func split(_ zone: UUID, sideBySide: Bool, ratio: Double) { edit { $0.splitting(zone, sideBySide: sideBySide, ratio: ratio) } }

    func setRatio(_ line: UUID, _ ratio: Double) { edit { $0.settingRatio(line, ratio) } }

    /// Removing the line in front of an area removes the area (the ones beyond it move in); any other line joins its two sides.
    func collapse(_ line: UUID) {
        if let i = strip.leading.firstIndex(where: { $0.id == line }) { strip.leading.remove(at: i) }
        else if let i = strip.trailing.firstIndex(where: { $0.id == line }) { strip.trailing.remove(at: i) }
        else { edit { $0.collapsing(line) } }
    }

    /// What merging two zones would give, or nil when it cannot be done.
    func merged(_ a: UUID, _ b: UUID) -> StripLayout? { strip.merging(a, b) }

    func merge(_ a: UUID, _ b: UUID) { if let result = merged(a, b) { strip = result } }

    private func edit(_ change: (LayoutNode) -> LayoutNode) {
        strip = StripLayout(composite: change(strip.composite), leadingIDs: strip.leading.map(\.id), trailingIDs: strip.trailing.map(\.id))
    }
}
