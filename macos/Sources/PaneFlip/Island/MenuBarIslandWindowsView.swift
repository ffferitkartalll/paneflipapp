import AppKit
import SwiftUI

/// The windows of the zone chosen in the picture, as a carousel like the one inside the zone: the window in front fills a frame as large as the zone, in
/// the middle under the picture, drawn as the frame of the screen is in the picture; the other windows lie against it, as wide as it, side by side with no gap and fading out toward the edges of the island, outlined
/// as the zones beyond the screen's edge are, and slide through the frame as another comes to the front (or as the fingers lead them). The picture of each
/// app stands in the middle of its window, dark where it is over the lit frame and light where it is not. The apps of the zone that are not open stand among them in the order of the zone (their pictures dimmer). The title of each is under it, and under that why an app is not open.
/// The rows are moved, never redrawn, and the masks stand still: a step costs the main thread next to nothing, which fast repeated steps need.
struct MenuBarIslandWindowsView: View {
    let model: MenuBarIslandModel

    var body: some View {
        let size = model.windowsFrame
        VStack(spacing: model.windowsGap) {
            if model.windows.isEmpty {
                Text("No windows")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: size.width, height: size.height)
                    .background(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5])))
            } else {
                carousel(size: size)
            }
            // The room under the cards: their titles are drawn in it, in the cells of the cards.
            Color.clear.frame(width: 1, height: model.captionHeight)
        }
        .id(model.windowsZone)   // another zone: its windows fade in as the old ones fade out
        .transition(.opacity)
    }

    /// What stands under a card: its title, and under that why an app is not open. Both are in the cell of the card, so they move with it.
    private func caption(_ window: IslandWindow) -> some View {
        let font = Font(NSFont.menuBarFont(ofSize: 0))   // as the date and the time of the menu bar
        return VStack(spacing: 0) {
            Text(verbatim: window.name)
                .font(font)
                .foregroundStyle(.white.opacity(window.isActive ? 1 : 0.55))
                .frame(maxWidth: .infinity)   // the text is centred in the width of its card, whatever that is while the card widens or narrows
                .frame(height: 16)
            Group {
                if let absence = window.absence { Text(absence.title) } else { Text(verbatim: " ") }
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 14)
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
    }

    /// The card the mouse carries lies above the others.
    private func lifted(_ card: some View, _ window: IslandWindow) -> some View {
        card.zIndex(model.liftedCard == window.id ? 1 : 0)
    }

    private func carousel(size: CGSize) -> some View {
        let wide = model.windowsSpan
        let icon = min(32, max(14, min(size.width, size.height) * 0.4))
        let frame = RoundedRectangle(cornerRadius: 3)
        func row(height: CGFloat? = nil, _ cell: @escaping (IslandWindow) -> AnyView) -> some View {
            IslandShiftedRow(model: model, size: CGSize(width: size.width, height: height ?? size.height)) { ForEach(model.windows) { lifted(cell($0), $0) } }
                .frame(width: wide, height: height ?? size.height, alignment: .top)
        }
        func picture(_ window: IslandWindow, _ ink: Color) -> AnyView {
            AnyView(Group {
                if let glyph = window.glyph {
                    Image(nsImage: glyph).renderingMode(.template).resizable().scaledToFit().foregroundStyle(window.windowID == nil && !window.isPlaceholder ? ink.opacity(0.5) : ink).frame(width: icon, height: icon)
                }
            })
        }
        // The frame goes with the card in front when the mouse carries that.
        let shift = model.frameShift
        // No window in front (the zone holds none that is open): no frame, and nothing is lit.
        let lit = model.cardsAt == nil ? 0 : size.width
        return ZStack(alignment: .top) {
            frame.fill(AppAccent.color).frame(width: lit, height: size.height).offset(x: shift)
            // A card the mouse carries is grey, its edge not dashed, whether it is over the frame or not (the front card has its frame).
            row { window in
                AnyView(RoundedRectangle(cornerRadius: 2).fill(.white.opacity((window.id == model.liftedCard || window.isPlaceholder) && !window.isActive ? 0.22 : 0)))
            }
            // Outside the frame: the outlines of the windows beyond it, and the pictures, light.
            ZStack(alignment: .top) {
                // Always the same shape, only dimmed while it is carried: it glides with the card to its place, and does not appear there.
                row { window in AnyView(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(window.id == model.liftedCard || window.isPlaceholder ? 0 : 0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))) }
                // The title and the line under the picture are in the cell of the card, in the same row, so that they move exactly as the card does.
                row(height: size.height + model.windowsGap + model.captionHeight) { window in
                    AnyView(VStack(spacing: model.windowsGap) {
                        picture(window, .white.opacity(0.9)).frame(height: size.height)
                        caption(window)
                    })
                }
            }
            .mask { ZStack(alignment: .top) { Rectangle(); frame.frame(width: lit, height: size.height).offset(x: shift).blendMode(.destinationOut) }.compositingGroup() }
            // Inside it: the pictures, dark.
            row { picture($0, AppAccent.ink) }
                .mask { frame.frame(width: lit, height: size.height).offset(x: shift) }
            frame.strokeBorder(.white.opacity(0.5), lineWidth: 1).frame(width: lit, height: size.height).offset(x: shift)
        }
        .frame(width: wide, height: size.height, alignment: .top)
        // The cards that go toward the edges of the island fade into it. The mask is as tall as the titles under the cards reach, which lie below the frame.
        .mask(alignment: .top) {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: model.barHeight / wide),
                                   .init(color: .black, location: 1 - model.barHeight / wide), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: wide, height: size.height + model.windowsGap + model.captionHeight)
        }
    }
}
