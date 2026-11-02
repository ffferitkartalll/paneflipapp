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
                IslandGlyph(model: model, gap: open ? 0 : model.notchWidth).offset(x: 0, y: glyphTop)
            } else {
                IslandGlyph(model: model, gap: 0).offset(x: glyphLeft + px(model.glyph.size.width * model.zoom) / 2, y: glyphTop)
            }
            if open || peek {
                // Under the picture, as wide as the room of the island; it grows out of the picture's foot as the island grows, and fades.
                MenuBarIslandWindowsView(model: model)
                    .frame(width: model.windowsSpan, height: model.windowsHeight, alignment: .top)
                    .clipped()
                    .offset(x: 0, y: model.windowsTop)
                    .opacity(model.windowsZone == nil ? 0 : model.contentOpacity)
                if let text = model.notice {
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
                    .offset(x: 0, y: model.noticeTop)
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
}
