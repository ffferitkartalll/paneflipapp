import AppKit
import PaneFlipCore
import SwiftUI

/// The zones drawn small, in one drawing: filled inside the frame of the screen, dashed outside it, so that the fill goes as far as a zone is in view.
/// One canvas, not a tree of views and masks: it is redrawn for every finger event of a scroll and must cost next to nothing. The shift of the frame is
/// what animates (the drawing is redone for every step of it).
struct GlyphCanvas: View, Animatable {
    let glyph: ZoneGlyph
    let texts: [UUID: String]
    var zoom: CGFloat
    /// The zoom the picture has when the island is open.
    let openZoom: CGFloat
    /// How much of the numbers of the zones shows: 1 while the island is open, 0 once it begins to shrink.
    var labels: CGFloat
    /// The zone whose windows are shown under the picture: outlined.
    let selectedID: UUID?
    /// The zone a window is being sent to.
    let pickedID: UUID?
    let previousPickedID: UUID?
    var pickBlend: CGFloat
    let activeID: UUID?
    let previousID: UUID?
    var blend: CGFloat
    var shift: CGFloat
    /// How far apart the two halves of the picture are drawn (the picture is cut in the middle, at a notch): the zones at the cut are stretched across.
    var gap: CGFloat
    let scale: CGFloat
    /// The colour of the drawing on its ground.
    let ink: IslandInk
    /// The zone the pointer is over, the one it left and how far the change has come: the lighter fill fades over.
    var hoveredID: UUID? = nil
    var previousHoveredID: UUID? = nil
    var hoverBlend: CGFloat = 1

    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>>>, CGFloat> {
        get { AnimatablePair(AnimatablePair(AnimatablePair(shift, gap), AnimatablePair(blend, AnimatablePair(zoom, AnimatablePair(labels, pickBlend)))), hoverBlend) }
        set {
            shift = newValue.first.first.first; gap = newValue.first.first.second; blend = newValue.first.second.first; zoom = newValue.first.second.second.first
            labels = newValue.first.second.second.second.first; pickBlend = newValue.first.second.second.second.second
            hoverBlend = newValue.second
        }
    }

    /// How much a zone is lit by the pointer: fading in as the pointer comes onto it, out as it leaves.
    private func hovered(_ id: UUID) -> CGFloat { id == hoveredID ? hoverBlend : (id == previousHoveredID ? 1 - hoverBlend : 0) }

    /// How much a zone is lit in the colour of the zone a window is sent to: fading in as it is chosen, out as another is.
    private func picked(_ id: UUID) -> CGFloat { id == pickedID ? pickBlend : (id == previousPickedID ? 1 - pickBlend : 0) }

    /// The fill of a zone: grey, or the lit colour, or between the two while the focus moves from one zone to another.
    private func lit(_ id: UUID) -> CGFloat { id == activeID ? blend : (id == previousID ? 1 - blend : 0) }

    private func fill(of id: UUID, accent: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> Color {
        let lit = lit(id)
        let base = CGFloat(ink.white)
        return Color(red: base + (accent.red - base) * lit, green: base + (accent.green - base) * lit, blue: base + (accent.blue - base) * lit, opacity: 0.28 + (1 - 0.28) * lit)
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
    /// A position in the picture drawn `zoom` times as large.
    private func sz(_ value: CGFloat) -> CGFloat { px(value * zoom) }

    /// A zone as it is drawn: the zones of the picture meet, so each is drawn a little inside (see `ZoneGlyph.inset`).
    private func inner(_ rect: CGRect) -> CGRect {
        stretched(plainInner(rect))
    }

    private func plainInner(_ rect: CGRect) -> CGRect {
        let inset = glyph.inset(zoom: zoom, openZoom: openZoom)
        let x0 = px(rect.minX * zoom + inset), x1 = px(rect.maxX * zoom - inset), y0 = px(rect.minY * zoom + inset), y1 = px(rect.maxY * zoom - inset)
        return CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
    }

    var body: some View {
        Canvas { context, _ in paint(&context) }
    }

    /// Where a rectangle is drawn when the picture is cut in the middle and its halves are `gap` apart (at a notch). A zone across the cut is made wider by the gap, and
    /// one that ends or begins at the cut grows to the middle of the gap, as the other zone beyond it does: the notch hides the middle, and the picture
    /// looks stretched there, not cut, while the island opens (with no gap nothing changes).
    private func stretched(_ r: CGRect) -> CGRect {
        guard gap > 0 else { return r }
        let cut = px(sz(glyph.size.width) / 2), tolerance = 2 * glyph.inset(zoom: zoom, openZoom: openZoom) + 0.5, half = gap / 2
        var minX = r.minX, maxX = r.maxX
        if minX < cut - tolerance && maxX > cut + tolerance {
            maxX += gap
        } else if maxX <= cut + tolerance {
            if maxX >= cut - tolerance { maxX += half }
        } else {
            minX += minX <= cut + tolerance ? gap - half : gap
            maxX += gap
        }
        return CGRect(x: minX, y: r.minY, width: maxX - minX, height: r.height)
    }

    private func paint(_ context: inout GraphicsContext) {
            // The accent is asked once for the whole picture: asking for it (a defaults lookup and a colour conversion) for every zone made the redraw slow.
            let accent = AppAccent.rgb, accentColor = AppAccent.color
            let screen = glyph.screen
            // Inside the picture whatever the rounding: at the far right end the frame would stand a fraction of a point past it.
            let width = sz(screen.width)
            let window = stretched(CGRect(x: min(max(sz(screen.minX) + shift * zoom, 0), max(sz(glyph.size.width) - width, 0)), y: sz(screen.minY), width: width, height: sz(screen.height)))
            let windowPath = Path(roundedRect: window, cornerRadius: 3)
            for cell in glyph.cells {
                let rect = inner(cell.rect)
                context.drawLayer { layer in
                    layer.clip(to: windowPath, options: .inverse)
                    layer.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2), with: .color(ink.color(0.5)),
                                 style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))
                }
            }
            for cell in glyph.cells {
                let rect = inner(cell.rect)
                let shape = Path(roundedRect: rect, cornerRadius: 2)
                context.drawLayer { layer in
                    layer.clip(to: windowPath)
                    layer.fill(shape, with: .color(fill(of: cell.id, accent: accent)))
                }
                // The zone with the focus is lit beyond the frame too (the zone it left fades out there); a zone without the focus is not filled out of view.
                if lit(cell.id) > 0 {
                    context.drawLayer { layer in
                        layer.clip(to: windowPath, options: .inverse)
                        layer.fill(shape, with: .color(accentColor.opacity(lit(cell.id))))
                    }
                }
                if hovered(cell.id) > 0 {
                    let hover = hovered(cell.id)
                    // Lighter on a grey zone, darker on a lit one (white would hardly show on it); a zone beyond the screen's edge is outlined, and lit the same way.
                    let on = max(lit(cell.id), picked(cell.id))
                    context.drawLayer { layer in
                        layer.clip(to: windowPath)
                        layer.fill(shape, with: .color(Color(white: ink.white * (1 - on)).opacity((0.2 + 0.1 * on) * hover)))
                    }
                    context.drawLayer { layer in
                        layer.clip(to: windowPath, options: .inverse)
                        layer.fill(shape, with: .color(ink.color(0.18 * hover)))
                    }
                }
                if picked(cell.id) > 0 { context.fill(shape, with: .color(AppAccent.placement.opacity(picked(cell.id)))) }
                if cell.id == selectedID {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 2), with: .color(ink.color(0.9)), lineWidth: 1.5)
                }
                if zoom > 1, let text = texts[cell.id] {
                    context.drawLayer { layer in
                        layer.clip(to: Path(rect))
                        // The ink on the grey zones, dark on the lit one (and between the two as the focus moves), as the date and the time of the menu bar are written.
                        let strength = max(picked(cell.id), lit(cell.id)), label = Color(white: ink.white + (0.08 - ink.white) * strength).opacity(min(zoom - 1, 1) * labels)
                        layer.draw(Text(verbatim: text).font(Font(NSFont.menuBarFont(ofSize: 0))).foregroundStyle(label), at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
            context.stroke(Path(roundedRect: window.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(ink.color(0.5)), lineWidth: 1)
    }
}
