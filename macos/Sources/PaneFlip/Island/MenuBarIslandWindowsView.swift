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
            // The room under the cards: their titles are drawn in it, in the cells of the cards (no windows, no titles).
            if !model.windows.isEmpty { Color.clear.frame(width: 1, height: model.captionHeight) }
        }
        .id(model.windowsZone)   // another zone: its windows fade in as the old ones fade out
        .transition(.opacity)
    }

    /// What stands under a card: its title, and why an app is not open in brackets after it. It is in the cell of the card, so they move with it.
    private func caption(_ window: IslandWindow) -> some View {
        let font = Font(NSFont.menuBarFont(ofSize: 0))   // as the date and the time of the menu bar
        return Text(verbatim: window.caption)
            .font(font)
            .foregroundStyle(.white.opacity(window.isActive ? 1 : 0.55))
            .frame(maxWidth: .infinity)   // the text is centred in the width of its card, whatever that is while the card widens or narrows
            .frame(height: model.captionHeight)
            .multilineTextAlignment(.center)
            .lineLimit(1)
    }

    /// The buttons of the card the mouse is over (nothing on the others, and nothing while a card is carried). They are drawn in the cards' own pictures, in both layers
    /// (`dark`: the layer inside the lit frame), so that they move exactly as the cards do and change from light to dark as the frame passes, as the app's picture does.
    private func actions(of window: IslandWindow, in size: CGSize, dark: Bool) -> some View {
        let shown = window.id == model.hoveredCard && window.hasButtons && model.carriedCard == nil
        return ZStack(alignment: .topLeading) {
            ForEach(IslandCardAction.rects(in: size, among: window.actions), id: \.action) { item in
                // The symbol is fitted into a box in the middle of the button: the symbols differ in their own bearings, a font size would not centre them.
                Image(systemName: item.action.symbol).resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                    .frame(width: item.rect.width * 0.5, height: item.rect.height * 0.5)
                    .frame(width: item.rect.width, height: item.rect.height)
                    .background(Circle().fill(Self.buttonFill(dark: dark, hover: model.hoveredButton == .card(item.action, window.id))))
                    .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
                    .offset(x: item.rect.minX, y: item.rect.minY)
            }
            selectButton(of: window, in: size, dark: dark)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: shown)   // only its own fade: the cards' motion is not touched
    }

    /// The fill of a card's round button: dark inside the lit frame, light outside it, and stronger while the pointer is on it.
    private static func buttonFill(dark: Bool, hover: Bool) -> Color { dark ? .black.opacity(hover ? 0.85 : 0.6) : .white.opacity(hover ? 0.45 : 0.28) }

    /// The button that ticks the card's app to be started with the layout: a circle like the others, which shows a check mark when the app is ticked.
    private func selectButton(of window: IslandWindow, in size: CGSize, dark: Bool) -> some View {
        let rect = IslandCardAction.selectRect(in: size), on = window.selected
        return ZStack {
            Circle().fill(Self.buttonFill(dark: dark, hover: model.hoveredButton == .select(window.id)))
                .animation(.easeOut(duration: 0.1), value: model.hoveredButton)
            Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(.white)
                .frame(width: rect.width * 0.5, height: rect.height * 0.5)
                .scaleEffect(on ? 1 : 0.3).opacity(on ? 1 : 0)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .animation(.easeOut(duration: 0.18), value: on)
    }

    private func badge(of window: IslandWindow, in size: CGSize) -> some View {
        let shown = window.badgeText != nil && !(window.id == model.hoveredCard && window.hasButtons && model.carriedCard == nil)
        // Where the remove button stands, as large as it.
        let rect = IslandCardAction.rects(in: size, among: [.remove]).first?.rect ?? .zero
        return ZStack(alignment: .topLeading) {
            if let text = window.badgeText {
                Text(verbatim: text)
                    .font(.system(size: rect.width * 0.5, weight: .bold)).foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .padding(.horizontal, 1)
                    .frame(width: rect.width, height: rect.height)
                    .background(Circle().fill(Color.red))
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .opacity(shown ? 1 : 0)
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
                    Image(nsImage: glyph).renderingMode(.template).resizable().interpolation(.high).antialiased(true).scaledToFit().foregroundStyle(window.windowID == nil && !window.isPlaceholder ? ink.opacity(0.5) : ink).frame(width: icon, height: icon)
                }
            })
        }
        // The frame goes with the card in front when the mouse carries that.
        let shift = model.frameShift
        // No window in front (the zone holds none that is open): no frame, and nothing is lit.
        let lit = model.cardsAt == nil ? 0 : size.width
        return ZStack(alignment: .top) {
            frame.fill(AppAccent.color).frame(width: lit, height: size.height).offset(x: shift)
            // The front card is on the lit frame, where white would hardly show: the frame darkens while the pointer is on that card.
            frame.fill(.black.opacity(model.windows.first(where: \.isActive)?.id == model.hoveredWindow && model.hoveredWindow != nil ? 0.14 : 0))
                .frame(width: lit, height: size.height).offset(x: shift)
                .animation(.easeOut(duration: 0.12), value: model.hoveredWindow)
            // A card the mouse carries is grey, its edge not dashed, whether it is over the frame or not (the front card has its frame).
            row { window in
                AnyView(RoundedRectangle(cornerRadius: 2).fill(.white.opacity((window.id == model.liftedCard || window.isPlaceholder) && !window.isActive ? 0.22 : (window.id == model.hoveredWindow && !window.isActive ? 0.14 : 0))).animation(.easeOut(duration: 0.12), value: model.hoveredWindow))
            }
            // Outside the frame: the outlines of the windows beyond it, and the pictures, light.
            ZStack(alignment: .top) {
                // Always the same shape, only dimmed while it is carried: it glides with the card to its place, and does not appear there.
                row { window in AnyView(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(window.id == model.liftedCard || window.isPlaceholder ? 0 : 0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))) }
                // The title and the line under the picture are in the cell of the card, in the same row, so that they move exactly as the card does.
                row(height: size.height + model.windowsGap + model.captionHeight) { window in
                    AnyView(VStack(spacing: model.windowsGap) {
                        ZStack { picture(window, .white.opacity(0.9)); actions(of: window, in: size, dark: false) }.frame(height: size.height)
                        caption(window)
                    })
                }
            }
            .mask { ZStack(alignment: .top) { Rectangle(); frame.frame(width: lit, height: size.height).offset(x: shift).blendMode(.destinationOut) }.compositingGroup() }
            // Inside it: the pictures, dark.
            row { window in AnyView(ZStack { picture(window, AppAccent.ink); actions(of: window, in: size, dark: true) }) }
                .mask { frame.frame(width: lit, height: size.height).offset(x: shift) }
            frame.strokeBorder(.white.opacity(0.5), lineWidth: 1).frame(width: lit, height: size.height).offset(x: shift)
            // The badges of the apps, on the top right of the cards, as the Dock has them; the buttons of the card under the mouse take their place.
            row { window in AnyView(badge(of: window, in: size)) }
        }
        .frame(width: wide, height: size.height, alignment: .top)
    }
}
