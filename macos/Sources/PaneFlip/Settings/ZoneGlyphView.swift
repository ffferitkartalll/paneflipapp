import PaneFlipCore
import SwiftUI

/// A layout's zones drawn small as the island draws them, the zones beyond the screen's edges dashed outside the frame of the screen, with one zone lit. With `onSelect` a click on a zone chooses it, and the zone under the pointer is lit lighter.
struct ZoneGlyphView: View {
    let strip: StripLayout
    let screenSize: CGSize
    /// The zone lit; none when it lies on another display.
    let zone: UUID?
    /// How wide the screen is drawn, the zones beyond its edges at the same scale; the height follows its shape.
    let screenWidth: CGFloat
    var onSelect: ((UUID) -> Void)?
    @State private var hovered: UUID?

    private var glyph: ZoneGlyph {
        let screen = CGRect(origin: .zero, size: screenSize)
        let zones = StripGeometry(strip: strip, screen: screen).zones(offset: 0).map { (id: $0.id, rect: $0.rect) }
        return ZoneGlyph(zones: zones, screen: screen, screenSize: CGSize(width: screenWidth, height: screenWidth * screenSize.height / max(screenSize.width, 1)))
    }

    var body: some View {
        let glyph = glyph
        Canvas { gc, _ in
            gc.translateBy(x: 1, y: 1)   // room for the strokes at the edges, which a fraction of a point would cut
            for cell in glyph.cells {
                let shape = Path(roundedRect: cell.rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2)
                defer { label(of: cell, in: &gc) }
                if cell.id == zone {
                    gc.fill(shape, with: .color(AppAccent.color))
                } else if cell.id == hovered {
                    gc.fill(shape, with: .color(.primary.opacity(0.55)))
                } else if cell.isOnScreen {
                    gc.fill(shape, with: .color(.primary.opacity(0.28)))
                } else {
                    gc.stroke(shape, with: .color(.secondary), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))
                }
            }
            gc.stroke(Path(roundedRect: glyph.screen.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.secondary), lineWidth: 1)
        }
        .frame(width: glyph.size.width + 2, height: glyph.size.height + 2)
        .contentShape(.rect)
        .onContinuousHover { phase in
            guard onSelect != nil else { return }
            if case .active(let point) = phase { hovered = cell(at: point, in: glyph) } else { hovered = nil }
        }
        .gesture(SpatialTapGesture().onEnded { if let onSelect, let id = cell(at: $0.location, in: glyph) { onSelect(id) } })
    }

    /// The zone's number in it (-1, 2, +1…), when it is wide enough to hold it; dark on the lit zone.
    private func label(of cell: ZoneGlyph.Cell, in gc: inout GraphicsContext) {
        guard cell.rect.width >= 9, cell.rect.height >= 9 else { return }
        let text = ZoneLabel.text(of: cell.id, in: strip)
        gc.draw(Text(verbatim: text).font(.system(size: 8, weight: .medium)).foregroundStyle(cell.id == zone ? AppAccent.ink : Color.primary.opacity(0.7)),
                at: CGPoint(x: cell.rect.midX, y: cell.rect.midY))
    }

    /// The zone at a point of the view (the drawing lies 1 pt in).
    private func cell(at point: CGPoint, in glyph: ZoneGlyph) -> UUID? {
        glyph.cells.first { $0.rect.offsetBy(dx: 1, dy: 1).contains(point) }?.id
    }
}
