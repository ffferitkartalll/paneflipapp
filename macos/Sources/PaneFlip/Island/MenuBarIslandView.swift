import AppKit
import PaneFlipCore
import SwiftUI

/// The island: a black shape hanging from the top edge, as tall as the menu bar. The picture of the zones lies left of the middle of the screen (left of
/// the notch, where there is one) and the name of the zone with the focus right of it. The middle stays where it is: the picture grows to the left, the name
/// to the right. Every edge of the island keeps the same margin around what it holds.
struct MenuBarIslandView: View {
    static let margin: CGFloat = 4
    let model: MenuBarIslandModel

    /// How much larger the picture is with the pointer on the island .
    static let hoverZoom: CGFloat = 5

    /// One island that is always fixed to the top of the screen. With the pointer on it, the same black shape reaches down below the menu bar, and the
    /// picture and the name move into it, side by side and centred; at rest the picture lies left of the notch (or the divider) and the name right of it.
    /// Every part is placed by hand, from the centre of the screen, so that all of them move with the same spring.
    var body: some View {
        let m = Self.margin, open = model.expanded
        let gw = model.glyph.size.width * (open ? model.openZoom : 1), gh = model.glyph.size.height * (open ? model.openZoom : 1)
        let lw = model.labelWidth, hasLabel = !model.label.isEmpty
        let gap = model.notchWidth > 0 ? model.notchWidth : (hasLabel ? 1 : 0)
        let bar = model.barHeight
        // Left and right edge of the shape, and the top of the picture and the left of the name.
        let left: CGFloat, right: CGFloat, glyphTop: CGFloat, labelLeft: CGFloat, height: CGFloat, inset: CGFloat
        if open {
            // The height of the menu bar again as room right, left and below.
            let width = 2 * bar + gw + (hasLabel ? 2 * m + lw : 0)
            left = -width / 2; right = width / 2
            inset = bar; glyphTop = bar; labelLeft = left + bar + gw + 2 * m; height = bar + gh + bar
        } else {
            left = -(2 * m + gw + gap / 2); right = gap / 2 + (hasLabel ? 2 * m + lw : 0)
            inset = m; glyphTop = m; labelLeft = gap / 2 + m; height = bar
        }
        return ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(.black)
                .frame(width: right - left, height: height)
                .offset(x: (left + right) / 2)
            glyph
                .offset(x: left + inset + px(model.glyph.size.width * model.zoom) / 2, y: glyphTop)
            if model.notchWidth == 0 && hasLabel {
                Rectangle().fill(.white.opacity(open ? 0 : 0.3))
                    // Gone at once when the island opens; back, fading in, only once it has closed again.
                    .animation(open ? nil : .easeIn(duration: 0.3).delay(0.4), value: open)
                    .frame(width: 1, height: bar)
            }
            if hasLabel {
                label
                    .frame(width: lw, height: open ? gh : bar)
                    .offset(x: labelLeft + lw / 2, y: open ? bar : 0)
            }
        }
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
        GlyphCanvas(glyph: model.glyph, texts: model.cellTexts, zoom: model.zoom, dropping: model.dropping, activeID: model.activeID, previousID: model.previousID, blend: model.blend, shift: model.outlineShift, scale: model.scale)
            .frame(width: px(model.glyph.size.width * model.zoom), height: px(model.glyph.size.height * model.zoom))
    }
}

/// The zones drawn small, in one drawing: filled inside the frame of the screen, dashed outside it, so that the fill goes as far as a zone is in view.
/// One canvas, not a tree of views and masks: it is redrawn for every finger event of a scroll and must cost next to nothing. The shift of the frame is
/// what animates (the drawing is redone for every step of it).
private struct GlyphCanvas: View, Animatable {
    let glyph: ZoneGlyph
    let texts: [UUID: String]
    var zoom: CGFloat
    let dropping: Bool
    let activeID: UUID?
    let previousID: UUID?
    var blend: CGFloat
    var shift: CGFloat
    let scale: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(shift, AnimatablePair(blend, zoom)) }
        set { shift = newValue.first; blend = newValue.second.first; zoom = newValue.second.second }
    }

    /// The fill of a zone: grey, or the lit colour, or between the two while the focus moves from one zone to another.
    private func fill(of id: UUID) -> Color {
        let lit = id == activeID ? blend : (id == previousID ? 1 - blend : 0)
        return Color(red: 1 + (0.23 - 1) * lit, green: 1 + (0.91 - 1) * lit, blue: 1 + (0.69 - 1) * lit, opacity: 0.28 + (1 - 0.28) * lit)
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
    /// A position in the picture drawn `zoom` times as large.
    private func sz(_ value: CGFloat) -> CGFloat { px(value * zoom) }

    var body: some View {
        Canvas { context, _ in
            let screen = glyph.screen
            // Inside the picture whatever the rounding: at the far right end the frame would stand a fraction of a point past it.
            let width = sz(screen.width)
            let window = CGRect(x: min(max(sz(screen.minX) + shift * zoom, 0), max(sz(glyph.size.width) - width, 0)), y: sz(screen.minY), width: width, height: sz(screen.height))
            let windowPath = Path(roundedRect: window, cornerRadius: 3)
            for cell in glyph.cells {
                // Half a point off every side: the zones, which meet, are 1 pt apart whatever the gap of the layout.
                let x0 = sz(cell.rect.minX + 0.5), x1 = sz(cell.rect.maxX - 0.5), y0 = sz(cell.rect.minY + 0.5), y1 = sz(cell.rect.maxY - 0.5)
                let rect = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
                context.drawLayer { layer in
                    layer.clip(to: windowPath, options: .inverse)
                    layer.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2), with: .color(.white.opacity(0.5)),
                                 style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))
                }
            }
            for cell in glyph.cells {
                let x0 = sz(cell.rect.minX + 0.5), x1 = sz(cell.rect.maxX - 0.5), y0 = sz(cell.rect.minY + 0.5), y1 = sz(cell.rect.maxY - 0.5)
                let rect = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
                context.drawLayer { layer in
                    if !dropping || (cell.id != activeID && cell.id != previousID) { layer.clip(to: windowPath) }
                    layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(fill(of: cell.id)))
                }
                if zoom > 1, let text = texts[cell.id] {
                    context.drawLayer { layer in
                        layer.clip(to: Path(rect))
                        let ink = Color.white.opacity(min(zoom - 1, 1))
                        layer.draw(Text(verbatim: text).font(.system(size: 11, weight: .semibold)).foregroundStyle(ink), at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
            context.stroke(Path(roundedRect: window.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}
