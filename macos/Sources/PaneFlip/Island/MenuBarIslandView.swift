import AppKit
import PaneFlipCore
import SwiftUI

/// The island: a black shape hanging from the top edge, as tall as the menu bar, with the picture of the zones in it, in the middle of the screen. Every edge of
/// the island keeps the same margin around the picture. Where there is a notch the island is not shown at rest (the middle of the screen is the notch): it grows
/// out of the notch when the pointer comes.
struct MenuBarIslandView: View {
    static let margin: CGFloat = 4
    let model: MenuBarIslandModel
    @Environment(\.colorScheme) private var scheme

    /// How much larger the picture is with the pointer on the island.
    static let hoverZoom: CGFloat = 5

    /// One island that is always fixed to the top of the screen. With the pointer on it, the same black shape reaches down below the menu bar and the
    /// picture grows inside it. Every part is placed by hand, from the centre of the screen, so that all of them move with the same spring.
    var body: some View {
        let m = Self.margin, open = model.expanded, lined = model.notice != nil && !open, bar = model.barHeight, size = model.openSize
        let split = model.notchWidth > 0 && !open   // at a notch the closed island lies in two halves, one each side of it
        let gw = model.glyph.size.width * (open ? model.openZoom : 1), gh = model.glyph.size.height * (open ? model.openZoom : 1)
        // The shape: its left and right edge and its height. The picture: where it begins, and how far from the top.
        let left: CGFloat, right: CGFloat, glyphLeft: CGFloat, glyphTop: CGFloat, height: CGFloat
        if open {
            // The height of the menu bar again as room right, left and below.
            left = -size.width / 2; right = size.width / 2
            glyphLeft = -gw / 2; glyphTop = model.topHeight; height = size.height   // in the middle: the island is wider than it when no zone waits beyond the edges
        } else if lined {
            // A notice: the picture stays as it is at rest, and the island holds its line under it.
            left = -size.width / 2; right = size.width / 2
            glyphLeft = -gw / 2; glyphTop = m; height = size.height
        } else if split {
            left = -(gw / 2 + model.notchWidth / 2 + m); right = -left
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        } else {
            left = -(gw / 2 + m); right = gw / 2 + m
            glyphLeft = -gw / 2; glyphTop = m; height = bar
        }
        let ink = model.ink(for: scheme)
        // Hanging from the top of the screen it is round at the bottom only; as a popover under the menu bar, all round.
        let top = model.popover ? IslandRim.radius : 0
        let outline = UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: IslandRim.radius, bottomTrailingRadius: IslandRim.radius, topTrailingRadius: top)
        return ZStack(alignment: .top) {
            outline.fill(model.ground)
                .frame(width: right - left, height: height)
                .overlay(alignment: .top) {
                    // Part of the shape, so they grow with it: as far from its edges as the picture is, and they appear once it has nearly grown.
                    if open {
                        HStack(spacing: model.cornerGap) {
                            ForEach(IslandCornerAction.allCases, id: \.self) { action in
                                // The symbol is fitted into a box by its own shape (a font size would centre the line of text, not the symbol).
                                HStack(spacing: MenuBarIslandModel.cornerSymbolGap) {
                                    Image(systemName: action.symbol).font(.system(size: 13))
                                        .frame(width: MenuBarIslandModel.cornerSymbol, height: MenuBarIslandModel.cornerSymbol)
                                    Text(verbatim: action.title).font(Font(MenuBarIslandModel.noticeFont)).lineLimit(1)
                                }
                                .foregroundStyle(ink.color())
                                .frame(width: model.cornerButtonWidth(action), height: MenuBarIslandModel.cornerHeight)
                                .background(Capsule().fill(ink.color(model.hoveredButton == .corner(action) ? 0.32 : 0.18)))
                                .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
                                if action == .openApps { Spacer(minLength: model.notchWidth) }
                            }
                        }
                        .padding(.top, (model.topHeight - MenuBarIslandModel.cornerHeight) / 2)
                        .padding(.horizontal, model.sideRoom)
                        .opacity(model.cornerButtonsOpacity)
                        .animation(.easeOut(duration: 0.1).delay(0.2), value: open)
                    }
                }
                .overlay(alignment: .top) {
                    // Under the picture, as wide as the room of the island; it grows out of the picture's foot as the island grows, and fades. Part of the shape, so
                    // that it is cut by the shape's edges while the island opens and closes, never seen outside it.
                    if open || lined {
                        MenuBarIslandWindowsView(model: model)
                            .frame(width: model.windowsSpan, height: model.windowsHeight, alignment: .top)
                            .clipped()
                            .offset(x: -(left + right) / 2, y: model.windowsTop)   // the shape is centred on (left + right) / 2, the row on the island's middle
                            .opacity(model.windowsZone == nil ? 0 : model.contentOpacity)
                    }
                }
                // A faint rim (sides and bottom), so the island shows against a black window behind it.
                .overlay { IslandRim(closed: model.popover).stroke(ink.color(0.18), lineWidth: 1) }
                .clipShape(outline)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                .offset(x: (left + right) / 2)
            if model.notchWidth > 0 {
                // At a notch the picture is cut in the middle, the halves apart by the notch's width while the island is closed (the left half ends at the
                // notch's left edge, the right half begins at its right edge, and the notch hides what is between); together once it is open.
                IslandGlyph(model: model, gap: open ? 0 : model.notchWidth).offset(x: 0, y: glyphTop)
            } else {
                IslandGlyph(model: model, gap: 0).offset(x: glyphLeft + px(model.glyph.size.width * model.zoom) / 2, y: glyphTop)
            }
            if open || lined {
                if let text = model.notice {
                    let radius = MenuBarIslandModel.noticeRadius, height = MenuBarIslandModel.noticeButtonHeight
                    HStack(spacing: MenuBarIslandModel.noticeGap) {
                        Text(text).font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(ink.color()).lineLimit(1).truncationMode(.tail)
                            .frame(width: model.noticeTextWidth, alignment: .leading)
                        Text(verbatim: model.noticeButtonTitle).font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(Color(white: 0.08))
                            .frame(width: model.noticeButtonWidth, height: height)
                            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(AppAccent.color).brightness(model.hoveredButton == .noticeUndo ? 0.15 : 0))
                            .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
                            .overlay {
                                // The notice that cannot be closed: the ring runs round the button that undoes it.
                                if !model.noticeCloses && !model.noticeEditing {
                                    ClockwiseRing(radius: radius - 1.5).inset(by: 1.5).trim(from: 1 - model.noticeLeft, to: 1)
                                        .stroke(Color(white: 0.08), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                }
                            }
                        if model.noticeCloses {
                            Image(systemName: "xmark").font(.system(size: 13)).foregroundStyle(ink.color())
                                .frame(width: height, height: height)
                                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(ink.color(model.hoveredButton == .noticeClose ? 0.32 : 0.18)))
                                .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
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
                if model.hasEditUndo {
                    let radius = MenuBarIslandModel.noticeRadius, height = MenuBarIslandModel.noticeButtonHeight
                    HStack(spacing: MenuBarIslandModel.noticeGap) {
                        Text(verbatim: MenuBarIslandModel.editUndoText).font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(ink.color()).lineLimit(1)
                            .frame(width: model.editUndoTextWidth, alignment: .leading)
                        Text("Undo").font(Font(MenuBarIslandModel.noticeFont)).foregroundStyle(Color(white: 0.08))
                            .frame(width: MenuBarIslandModel.editUndoButtonWidth, height: height)
                            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(AppAccent.color).brightness(model.hoveredButton == .noticeRevert ? 0.15 : 0))
                            .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
                    }
                    .offset(x: 0, y: model.noticeEditUndoTop)
                    .opacity(model.contentOpacity)
                }
                if model.pickedID != nil {
                    Text(verbatim: model.pickingNote)
                        .font(Font(MenuBarIslandModel.pickingNoteFont))
                        .foregroundStyle(ink.color())
                        .multilineTextAlignment(.center)
                        .frame(width: model.cardsFit, height: model.pickingNoteHeight, alignment: .top)
                        .offset(x: 0, y: model.topHeight + gh + model.windowsGap)
                        .opacity(model.contentOpacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.glyph.size)
        .overlay(alignment: .top) {
            // The arrow of the popover, in the room above it, under the menu bar icon (and no nearer a corner than the shape is round).
            if model.popover, let x = model.arrowX {
                let arrow = MenuBarIslandModel.arrowSize, reach = IslandRim.radius + arrow.width / 2
                ZStack {
                    IslandArrow().fill(model.ground)
                    IslandArrow(edgeOnly: true).stroke(ink.color(0.18), lineWidth: 1)
                }
                .frame(width: arrow.width, height: arrow.height)
                .offset(x: min(max(x, left + reach), right - reach), y: -arrow.height)
            }
        }
        .opacity(model.isHidden ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: model.isHidden)
        .padding(.top, model.arrowBand)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A popover grows out of the menu bar icon and shrinks back into it: it is scaled about the tip of its arrow (the panel is as wide as the display).
        .scaleEffect(model.popoverScale, anchor: UnitPoint(x: 0.5 + (model.arrowX ?? 0) / max(model.displayWidth, 1), y: 0))
        .ignoresSafeArea()   // the panel lies under the notch: the safe area would push the island down
    }

    private func px(_ value: CGFloat) -> CGFloat { (value * model.scale).rounded() / model.scale }
}
