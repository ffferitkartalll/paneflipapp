import Foundation

/// Zones beyond one side of the screen, reached by scrolling the whole layout. It is a layout of its own, as tall as the
/// screen.
public struct Overflow: Codable, Equatable {
    /// The line between the screen and this area (the editor drags it to change `width`).
    public var id: UUID
    /// In screen widths: 0.25 is a quarter of the screen.
    public var width: Double
    public var root: LayoutNode

    public init(id: UUID = UUID(), width: Double = 0.25, root: LayoutNode = .leaf(UUID())) {
        self.id = id
        self.width = width
        self.root = root
    }
}
