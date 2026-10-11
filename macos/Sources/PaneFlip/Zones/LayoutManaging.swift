import Foundation
import PaneFlipCore

/// What the UI may do to layouts. The settings window and the editor depend on this, not on the service.
protocol LayoutManaging: AnyObject {
    @discardableResult func addLayout(for key: String) -> NamedLayout
    func updateLayout(key: String, id: UUID, root: LayoutNode)
    func removeLayout(key: String, id: UUID)
    func activate(key: String, id: UUID)
    func rename(key: String, id: UUID, to name: String)
}
