import CoreGraphics
import Foundation
import Observation
import PaneFlipCore

/// Editing state for one layout. Nothing reaches the app until `apply()`.
@Observable
final class EditorModel {
    var root: LayoutNode
    var hover: CGPoint?
    var shift = false
    /// Zone being dragged onto a neighbour to merge, and where the pointer is.
    var mergeSource: UUID?
    var dragPoint: CGPoint?

    @ObservationIgnored private let onApply: (LayoutNode) -> Void
    @ObservationIgnored private let onClose: () -> Void

    init(root: LayoutNode, onApply: @escaping (LayoutNode) -> Void, onClose: @escaping () -> Void) {
        self.root = root
        self.onApply = onApply
        self.onClose = onClose
    }

    func apply() {
        onApply(root)
        onClose()
    }

    func close() { onClose() }

    func reset() { root = .leaf(root.leafIDs[0]) }
}
