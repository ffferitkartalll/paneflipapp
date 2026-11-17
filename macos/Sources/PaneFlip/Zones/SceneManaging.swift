import Foundation
import PaneFlipCore

/// What the Scenes tab and the menu ask of the scenes.
protocol SceneManaging: AnyObject {
    /// Makes a scene the one in use: each display takes the layout the scene names for it.
    func select(id: UUID)
    @discardableResult func addScene() -> DisplayScene
    func rename(id: UUID, to name: String)
    func remove(id: UUID)
    /// Puts a scene back as it starts (the default scene cannot be removed, only reset).
    func reset(id: UUID)
    func setLayout(sceneID: UUID, display: String, layoutID: UUID)
    /// The zones the windows of `zone` go to when its display is unplugged, the first to try first; none: they go where the layouts say.
    func setMoves(sceneID: UUID, zone: UUID, to destinations: [UUID])
}
