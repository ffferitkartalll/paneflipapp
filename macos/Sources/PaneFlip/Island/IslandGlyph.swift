import AppKit
import PaneFlipCore
import SwiftUI

/// The picture of the zones, a view of its own: the shift of the frame animates (a redraw for every step of the glide), and only this view reads it, so the rest of
/// the island is not worked out again for every step.
struct IslandGlyph: View {
    let model: MenuBarIslandModel
    let gap: CGFloat
    @Environment(\.colorScheme) private var scheme

    private func px(_ value: CGFloat) -> CGFloat { (value * model.scale).rounded() / model.scale }

    var body: some View {
        GlyphCanvas(glyph: model.glyph, texts: model.cellTexts, zoom: model.zoom, openZoom: model.openZoom, labels: model.contentOpacity, selectedID: model.windowsZone, pickedID: model.pickedID, previousPickedID: model.previousPickedID, pickBlend: model.pickBlend, activeID: model.activeID, previousID: model.previousID, blend: model.blend, shift: model.outlineShift, gap: gap, scale: model.scale, ink: model.ink(for: scheme), hoveredID: model.hoveredZone, previousHoveredID: model.previousHoveredZone, hoverBlend: model.zoneHoverBlend)
            .frame(width: px(model.glyph.size.width * model.zoom) + gap, height: px(model.glyph.size.height * model.zoom))
    }
}
