import Foundation

extension NamedLayout {
    /// The layout every display starts with, and the one a layout is reset to: one zone, no space between zones or round the screen, nothing beyond the edges.
    public static func standard(name: String, id: UUID = UUID()) -> NamedLayout {
        var layout = NamedLayout(id: id, name: name, root: LayoutPreset.single.root)
        layout.gap = 0
        layout.edgeMargin = 0
        return layout
    }
}
