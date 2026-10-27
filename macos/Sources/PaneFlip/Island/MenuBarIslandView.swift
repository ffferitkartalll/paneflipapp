import AppKit
import PaneFlipCore
import SwiftUI

/// The island: a black shape hanging from the top edge, as tall as the menu bar, with the picture of the zones in it, in the middle of the screen. Every edge of
/// the island keeps the same margin around the picture. Where there is a notch the island is not shown at rest (the middle of the screen is the notch): it grows
/// out of the notch when the pointer comes.
struct MenuBarIslandView: View {
    static let margin: CGFloat = 4
    let model: MenuBarIslandModel

    /// How much larger the picture is with the pointer on the island.
    static let hoverZoom: CGFloat = 5

    /// One island that is always fixed to the top of the screen. With the pointer on it, the same black shape reaches down below the menu bar and the
    /// picture grows inside it. Every part is placed by hand, from the centre of the screen, so that all of them move with the same spring.
    var body: some View {
        let m = Self.margin, open = model.expanded, bar = model.barHeight, size = model.openSize
        let hidden = model.notchWidth > 0 && !open
        let gw = model.glyph.size.width * (open ? model.openZoom : 1), gh = model.glyph.size.height * (open ? model.openZoom : 1)
        // The shape: its left and right edge and its height. The picture: where it begins, and how far from the top.
        let left: CGFloat, right: CGFloat, glyphLeft: CGFloat, glyphTop: CGFloat, height: CGFloat
        if open {
            // The height of the menu bar again as room right, left and below.
            left = -size.width / 2; right = size.width / 2
            glyphLeft = left + bar; glyphTop = bar; height = size.height
        } else if hidden {
            left = -model.notchWidth / 2; right = model.notchWidth / 2   // no more than the notch itself; the picture is there, but not shown
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        } else {
            left = -(gw / 2 + m); right = gw / 2 + m
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        }
        return ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(.black)
                .frame(width: right - left, height: height)
                .offset(x: (left + right) / 2)
            glyph
                .offset(x: glyphLeft + px(model.glyph.size.width * model.zoom) / 2, y: glyphTop)
                .opacity(hidden ? 0 : 1)
            if open {
                // Under the picture, as wide as it; it grows out of the picture's foot as the island grows, and fades.
                MenuBarIslandWindowsView(model: model)
                    .frame(width: gw, height: model.windowsHeight, alignment: .top)
                    .clipped()
                    .offset(x: glyphLeft + gw / 2, y: bar + gh + model.windowsGap)
                    .opacity(model.windowsZone == nil ? 0 : model.contentOpacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: model.glyph.size)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()   // the panel lies under the notch: the safe area would push the island down
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * model.scale).rounded() / model.scale }

    private var glyph: some View {
        GlyphCanvas(glyph: model.glyph, texts: model.cellTexts, zoom: model.zoom, openZoom: model.openZoom, labels: model.contentOpacity, selectedID: model.windowsZone, activeID: model.activeID, previousID: model.previousID, blend: model.blend, shift: model.outlineShift, scale: model.scale)
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
    /// The zoom the picture has when the island is open.
    let openZoom: CGFloat
    /// How much of the numbers of the zones shows: 1 while the island is open, 0 once it begins to shrink.
    var labels: CGFloat
    /// The zone whose windows are shown under the picture: outlined.
    let selectedID: UUID?
    let activeID: UUID?
    let previousID: UUID?
    var blend: CGFloat
    var shift: CGFloat
    let scale: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get { AnimatablePair(shift, AnimatablePair(blend, AnimatablePair(zoom, labels))) }
        set { shift = newValue.first; blend = newValue.second.first; zoom = newValue.second.second.first; labels = newValue.second.second.second }
    }

    /// The fill of a zone: grey, or the lit colour, or between the two while the focus moves from one zone to another.
    private func lit(_ id: UUID) -> CGFloat { id == activeID ? blend : (id == previousID ? 1 - blend : 0) }

    private func fill(of id: UUID) -> Color {
        let lit = lit(id), accent = AppAccent.rgb
        return Color(red: 1 + (accent.red - 1) * lit, green: 1 + (accent.green - 1) * lit, blue: 1 + (accent.blue - 1) * lit, opacity: 0.28 + (1 - 0.28) * lit)
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
    /// A position in the picture drawn `zoom` times as large.
    private func sz(_ value: CGFloat) -> CGFloat { px(value * zoom) }

    /// A zone as it is drawn: the zones of the picture meet, so each is drawn a little inside (see `ZoneGlyph.inset`).
    private func inner(_ rect: CGRect) -> CGRect {
        let inset = glyph.inset(zoom: zoom, openZoom: openZoom)
        let x0 = px(rect.minX * zoom + inset), x1 = px(rect.maxX * zoom - inset), y0 = px(rect.minY * zoom + inset), y1 = px(rect.maxY * zoom - inset)
        return CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
    }

    var body: some View {
        Canvas { context, _ in
            let screen = glyph.screen
            // Inside the picture whatever the rounding: at the far right end the frame would stand a fraction of a point past it.
            let width = sz(screen.width)
            let window = CGRect(x: min(max(sz(screen.minX) + shift * zoom, 0), max(sz(glyph.size.width) - width, 0)), y: sz(screen.minY), width: width, height: sz(screen.height))
            let windowPath = Path(roundedRect: window, cornerRadius: 3)
            for cell in glyph.cells {
                let rect = inner(cell.rect)
                context.drawLayer { layer in
                    layer.clip(to: windowPath, options: .inverse)
                    layer.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2), with: .color(.white.opacity(0.5)),
                                 style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))
                }
            }
            for cell in glyph.cells {
                let rect = inner(cell.rect)
                let shape = Path(roundedRect: rect, cornerRadius: 2)
                context.drawLayer { layer in
                    layer.clip(to: windowPath)
                    layer.fill(shape, with: .color(fill(of: cell.id)))
                }
                // The zone with the focus is lit beyond the frame too (the zone it left fades out there); a zone without the focus is not filled out of view.
                if lit(cell.id) > 0 {
                    context.drawLayer { layer in
                        layer.clip(to: windowPath, options: .inverse)
                        layer.fill(shape, with: .color(AppAccent.color.opacity(lit(cell.id))))
                    }
                }
                if cell.id == selectedID {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 2), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                }
                if zoom > 1, let text = texts[cell.id] {
                    context.drawLayer { layer in
                        layer.clip(to: Path(rect))
                        // White on the grey zones, dark on the lit one (and between the two as the focus moves), as the date and the time of the menu bar are written.
                        let ink = Color(white: 1 - 0.92 * lit(cell.id)).opacity(min(zoom - 1, 1) * labels)
                        layer.draw(Text(verbatim: text).font(Font(NSFont.menuBarFont(ofSize: 0))).foregroundStyle(ink), at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
            context.stroke(Path(roundedRect: window.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}
