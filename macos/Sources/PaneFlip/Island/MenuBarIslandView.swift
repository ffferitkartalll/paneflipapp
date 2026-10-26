import AppKit
import PaneFlipCore
import SwiftUI

/// The island: a black shape hanging from the top edge, as tall as the menu bar. The picture of the zones lies left of the middle of the screen (left of
/// the notch, where there is one) and the name of the zone with the focus right of it. The middle stays where it is: the picture grows to the left, the name
/// to the right. Every edge of the island keeps the same margin around what it holds.
struct MenuBarIslandView: View {
    static let margin: CGFloat = 4
    let model: MenuBarIslandModel

    var body: some View {
        let m = Self.margin
        HStack(spacing: 0) {
            glyph.padding(.horizontal, m)
            if model.notchWidth > 0 { Color.clear.frame(width: model.notchWidth) } else {
                Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: model.barHeight)
            }
            if model.label.isEmpty { Color.clear.frame(width: m) } else { label.padding(.horizontal, m) }
        }
        .frame(height: model.barHeight)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(.black))
        .alignmentGuide(HorizontalAlignment.center) { _ in 2 * m + model.glyph.size.width + (model.notchWidth > 0 ? model.notchWidth : 1) / 2 }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.glyph.size)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.labelWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()   // the panel lies under the notch: the safe area would push the island down
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * model.scale).rounded() / model.scale }

    private var label: some View {
        Text(verbatim: model.label).font(Font(NSFont.menuBarFont(ofSize: 0))).foregroundStyle(.white).lineLimit(1)
    }

    private var glyph: some View {
        GlyphCanvas(glyph: model.glyph, activeID: model.activeID, previousID: model.previousID, blend: model.blend, shift: model.outlineShift, scale: model.scale)
            .frame(width: px(model.glyph.size.width), height: px(model.glyph.size.height))
    }
}

/// The zones drawn small, in one drawing: filled inside the frame of the screen, dashed outside it, so that the fill goes as far as a zone is in view.
/// One canvas, not a tree of views and masks: it is redrawn for every finger event of a scroll and must cost next to nothing. The shift of the frame is
/// what animates (the drawing is redone for every step of it).
private struct GlyphCanvas: View, Animatable {
    let glyph: ZoneGlyph
    let activeID: UUID?
    let previousID: UUID?
    var blend: CGFloat
    var shift: CGFloat
    let scale: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shift, blend) }
        set { shift = newValue.first; blend = newValue.second }
    }

    /// The fill of a zone: grey, or the lit colour, or between the two while the focus moves from one zone to another.
    private func fill(of id: UUID) -> Color {
        let lit = id == activeID ? blend : (id == previousID ? 1 - blend : 0)
        return Color(red: 1 + (0.23 - 1) * lit, green: 1 + (0.91 - 1) * lit, blue: 1 + (0.69 - 1) * lit, opacity: 0.28 + (1 - 0.28) * lit)
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }

    var body: some View {
        Canvas { context, _ in
            let screen = glyph.screen
            // Inside the picture whatever the rounding: at the far right end the frame would stand a fraction of a point past it.
            let width = px(screen.width)
            let window = CGRect(x: min(max(px(screen.minX) + shift, 0), max(px(glyph.size.width) - width, 0)), y: px(screen.minY), width: width, height: px(screen.height))
            let windowPath = Path(roundedRect: window, cornerRadius: 3)
            for cell in glyph.cells {
                // Half a point off every side: the zones, which meet, are 1 pt apart whatever the gap of the layout.
                let x0 = px(cell.rect.minX + 0.5), x1 = px(cell.rect.maxX - 0.5), y0 = px(cell.rect.minY + 0.5), y1 = px(cell.rect.maxY - 0.5)
                let rect = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
                context.drawLayer { layer in
                    layer.clip(to: windowPath, options: .inverse)
                    layer.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2), with: .color(.white.opacity(0.5)),
                                 style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))
                }
            }
            for cell in glyph.cells {
                let x0 = px(cell.rect.minX + 0.5), x1 = px(cell.rect.maxX - 0.5), y0 = px(cell.rect.minY + 0.5), y1 = px(cell.rect.maxY - 0.5)
                let rect = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
                context.drawLayer { layer in
                    layer.clip(to: windowPath)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(fill(of: cell.id)))
                }
            }
            context.stroke(Path(roundedRect: window.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}
