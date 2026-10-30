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
        let m = Self.margin, open = model.expanded, peek = (model.peeking || model.notice != nil) && !open, bar = model.barHeight, size = model.openSize
        let split = model.notchWidth > 0 && !open   // at a notch the closed island lies in two halves, one each side of it
        let gw = model.glyph.size.width * (open ? model.openZoom : 1), gh = model.glyph.size.height * (open ? model.openZoom : 1)
        // The shape: its left and right edge and its height. The picture: where it begins, and how far from the top.
        let left: CGFloat, right: CGFloat, glyphLeft: CGFloat, glyphTop: CGFloat, height: CGFloat
        if open {
            // The height of the menu bar again as room right, left and below.
            left = -size.width / 2; right = size.width / 2
            glyphLeft = -gw / 2; glyphTop = bar; height = size.height   // in the middle: the island is wider than it when no zone waits beyond the edges
        } else if peek {
            // Only the windows of a zone: the picture stays as it is at rest, and the island is as wide as the cards need.
            left = -size.width / 2; right = size.width / 2
            glyphLeft = -gw / 2; glyphTop = m; height = size.height
        } else if split {
            left = -(gw / 2 + model.notchWidth / 2 + m); right = -left
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        } else {
            left = -(gw / 2 + m); right = gw / 2 + m
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        }
        return ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10).fill(.black)
                .frame(width: right - left, height: height)
                .offset(x: (left + right) / 2)
            if model.notchWidth > 0 {
                // At a notch the picture is cut in the middle, the halves apart by the notch's width while the island is closed (the left half ends at the
                // notch's left edge, the right half begins at its right edge, and the notch hides what is between); together once it is open.
                glyph(gap: open ? 0 : model.notchWidth).offset(x: 0, y: glyphTop)
            } else {
                glyph(gap: 0).offset(x: glyphLeft + px(model.glyph.size.width * model.zoom) / 2, y: glyphTop)
            }
            if open || peek {
                // Under the picture, as wide as the room of the island; it grows out of the picture's foot as the island grows, and fades.
                MenuBarIslandWindowsView(model: model)
                    .frame(width: model.windowsSpan, height: model.windowsHeight, alignment: .top)
                    .clipped()
                    .offset(x: 0, y: bar + (peek ? 0 : gh) + model.windowsGap)
                    .opacity(model.windowsZone == nil ? 0 : model.contentOpacity)
                if let text = model.notice, peek {
                    let radius = MenuBarIslandModel.noticeRadius, height = MenuBarIslandModel.noticeButtonHeight
                    HStack(spacing: MenuBarIslandModel.noticeGap) {
                        Text(text).font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(.white).lineLimit(1).truncationMode(.tail)
                            .frame(width: model.noticeTextWidth, alignment: .leading)
                        Text(verbatim: model.noticeButtonTitle).font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(Color(white: 0.08))
                            .frame(width: model.noticeButtonWidth, height: height)
                            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(AppAccent.color))
                            .overlay {
                                // The notice that cannot be closed: the ring runs round the button that undoes it.
                                if !model.noticeCloses {
                                    ClockwiseRing(radius: radius - 1.5).inset(by: 1.5).trim(from: 1 - model.noticeLeft, to: 1)
                                        .stroke(Color(white: 0.08), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                }
                            }
                        if model.noticeCloses {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .frame(width: height, height: height)
                                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.white.opacity(0.18)))
                                .overlay {
                                    // From twelve o'clock, clockwise; the time that has passed is taken from the start, so the ring runs down clockwise.
                                    Circle().inset(by: 1).trim(from: 1 - model.noticeLeft, to: 1).rotation(.degrees(-90))
                                        .stroke(AppAccent.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                }
                        }
                    }
                    .offset(x: 0, y: bar + model.windowsGap)
                    .opacity(model.contentOpacity)
                }
                if model.pickedID != nil {
                    Text(verbatim: model.pickingNote)
                        .font(Font(MenuBarIslandModel.pickingNoteFont))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: model.cardsFit, height: model.pickingNoteHeight, alignment: .top)
                        .offset(x: 0, y: bar + gh + model.windowsGap)
                        .opacity(model.contentOpacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.glyph.size)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()   // the panel lies under the notch: the safe area would push the island down
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * model.scale).rounded() / model.scale }

    private func glyph(gap: CGFloat) -> some View {
        GlyphCanvas(glyph: model.glyph, texts: model.cellTexts, zoom: model.zoom, openZoom: model.openZoom, labels: model.contentOpacity, selectedID: model.windowsZone, pickedID: model.pickedID, previousPickedID: model.previousPickedID, pickBlend: model.pickBlend, activeID: model.activeID, previousID: model.previousID, blend: model.blend, shift: model.outlineShift, gap: gap, scale: model.scale)
            .frame(width: px(model.glyph.size.width * model.zoom) + gap, height: px(model.glyph.size.height * model.zoom))
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

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>>> {
        get { AnimatablePair(AnimatablePair(shift, gap), AnimatablePair(blend, AnimatablePair(zoom, AnimatablePair(labels, pickBlend)))) }
        set {
            shift = newValue.first.first; gap = newValue.first.second; blend = newValue.second.first; zoom = newValue.second.second.first
            labels = newValue.second.second.second.first; pickBlend = newValue.second.second.second.second
        }
    }

    /// How much a zone is lit in the colour of the zone a window is sent to: fading in as it is chosen, out as another is.
    private func picked(_ id: UUID) -> CGFloat { id == pickedID ? pickBlend : (id == previousPickedID ? 1 - pickBlend : 0) }

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
            let screen = glyph.screen
            // Inside the picture whatever the rounding: at the far right end the frame would stand a fraction of a point past it.
            let width = sz(screen.width)
            let window = stretched(CGRect(x: min(max(sz(screen.minX) + shift * zoom, 0), max(sz(glyph.size.width) - width, 0)), y: sz(screen.minY), width: width, height: sz(screen.height)))
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
                if picked(cell.id) > 0 { context.fill(shape, with: .color(AppAccent.placement.opacity(picked(cell.id)))) }
                if cell.id == selectedID {
                    context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 2), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                }
                if zoom > 1, let text = texts[cell.id] {
                    context.drawLayer { layer in
                        layer.clip(to: Path(rect))
                        // White on the grey zones, dark on the lit one (and between the two as the focus moves), as the date and the time of the menu bar are written.
                        let ink = Color(white: 1 - 0.92 * max(picked(cell.id), lit(cell.id))).opacity(min(zoom - 1, 1) * labels)
                        layer.draw(Text(verbatim: text).font(Font(NSFont.menuBarFont(ofSize: 0))).foregroundStyle(ink), at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
            context.stroke(Path(roundedRect: window.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.white.opacity(0.5)), lineWidth: 1)
    }
}

/// A rounded rectangle drawn from the middle of its top edge, clockwise: trimmed, it runs down from twelve o'clock like a clock's hand.
private struct ClockwiseRing: InsettableShape {
    let radius: CGFloat
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> ClockwiseRing { ClockwiseRing(radius: radius, inset: inset + amount) }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset), corner = min(radius, r.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.midX, y: r.minY), radius: corner)
        path.closeSubpath()
        return path
    }
}
