import AppKit
import SwiftUI

/// One card of the grid of a zone's windows: the picture of the window (the glyph of its app where it has none: an app that is not open), with its title at the top and,
/// on the card under the pointer, the buttons of the island's cards.
struct ZoneWindowsCard: View {
    let model: ZoneWindowsModel
    let card: IslandWindow
    /// The size of the card: the same for every card, an app that is not open too. The picture of a window is scaled to it, not kept to its own shape.
    let size: CGSize
    /// False: the card shows the glyph of its app, as one that has no picture does.
    var showsPicture = true
    @State private var hoveredButton: IslandButton?
    /// The buttons and the accent frame stay in the card while they fade out.
    @State private var buttonsMounted = false
    @State private var frameMounted = false

    /// How far the title and the buttons stand further inside the card than the island's cards have them: they lie on the picture, in the accent colour, and must be seen to
    /// belong to the card.
    private static let inset: CGFloat = 6

    /// As large as the picture of the app on a card of the island's row: never large on a large card.
    private static func glyphSide(in size: CGSize) -> CGFloat { min(32, max(14, min(size.width, size.height) * 0.4)) }

    var body: some View {
        let picture = showsPicture ? model.pictures[card.id] : nil
        let radius = picture.map { $0.cornerRadius * size.width / max($0.frame.width, 1) } ?? 8
        ZStack(alignment: .topLeading) {
            if let picture {
                Image(decorative: picture.image, scale: 1).resizable().interpolation(.high).frame(width: size.width, height: size.height)
            } else {
                RoundedRectangle(cornerRadius: radius).fill(Color.contrast.opacity(0.1))
                if let glyph = card.glyph {
                    (model.glyphPicture(glyph).map { Image(decorative: $0, scale: 2) } ?? Image(nsImage: glyph)).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                        .foregroundStyle(AppAccent.color)
                        .frame(width: Self.glyphSide(in: size), height: Self.glyphSide(in: size))
                        .frame(width: size.width, height: size.height)
                        .modifier(Unsqueezed(model: model))   // not squeezed with the grid
                }
            }
            title
            buttons
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        // The edge and the shadow macOS gives a window that is not in focus, measured on one: a light line of 1 point inside the edge, a dark one outside it, and a shadow
        // (black, blurred 16, 5 points lower). They come with the cards: over its window the picture must not differ from it.
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: radius).strokeBorder(CardEdge.inner, lineWidth: 1)
                RoundedRectangle(cornerRadius: radius + 1).strokeBorder(CardEdge.outer, lineWidth: 1).padding(-1)
            }
            .modifier(AppearOpacity(model: model))
        }
        // The shadow is cast by a plain shape behind the card, not by the picture: blurring a large picture again at every step of the slide made the grid late in showing.
        // The shadow itself stays as it is and only its layer fades in: a blur whose colour changes is drawn again at every step of the slide, one that only fades is not.
        .background { RoundedRectangle(cornerRadius: radius).fill(CardEdge.ground).shadow(color: CardEdge.shadow, radius: 16, y: 5).modifier(AppearOpacity(model: model)) }
        // Two frames in the accent colour, which come and go softly (and with the cards: over its window the picture must not differ from it): the card with the focus
        // (the window in front) has the thickness of the frame that shows where the focus went between zones, the card to be chosen (under the pointer, or where the arrow keys
        // went) twice that: where the focus is, and where a click or Return would send it, are always told apart.
        .overlay {
            let focused = model.highlighted == card.id, pointed = (model.pointed == card.id || (focused && !(model.chosenAnywhere ?? (model.pointed != nil)))) && model.carried == nil
            // Only a card with a frame (or one fading out) has it: the others have nothing to draw or to follow the slide with.
            ZStack {
                if focused || pointed || frameMounted {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(AppAccent.color, lineWidth: pointed ? 2 * ZoneFlash.lineWidth : ZoneFlash.lineWidth)
                        .opacity(focused || pointed ? 1 : 0)
                        .modifier(AppearOpacity(model: model))
                        .transition(.opacity)
                        .task(id: focused || pointed) { await keep(focused || pointed, for: 0.15) { frameMounted = $0 } }
                }
            }
            .animation(.easeOut(duration: 0.15), value: focused)
            .animation(.easeOut(duration: 0.15), value: pointed)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                guard !model.ignoresHover else { return }
                if model.hovered != card.id { model.hovered = card.id }
                if model.pointed != card.id { model.pointed = card.id }
            case .ended:
                if model.hovered == card.id { model.hovered = nil }
                if model.pointed == card.id { model.pointed = nil }   // an arrow key may have taken it to another card meanwhile: that one stays
            }
        }
    }

    private var buttonsShown: Bool { model.settled && model.hovered == card.id && model.carried == nil && card.hasButtons }

    /// The title of the window, over the top of its picture, between the buttons of the card (a narrow card shows it only while the buttons do not). It is drawn once as a picture
    /// (`titlePicture`): text and shadow drawn as they are would be painted again at every step the card is scaled in.
    private var title: some View {
        let rects = IslandCardAction.rects(in: size, among: card.actions).map(\.rect)
        let room = size.width - 2 * ((rects.filter { $0.midX < size.width / 2 }.map(\.maxX).max() ?? 4) + Self.inset + 6)
        let shown = room >= 60 || !buttonsShown
        let width = shown && buttonsShown ? max(room, 0) : max(size.width - 2 * (8 + Self.inset), 0)
        // The picture has room round the label for its shadow.
        let margin: CGFloat = 8
        return Group {
            if let picture = model.titlePicture("\(card.caption)|\(Int(width * 4))", content: { titleLabel(maxWidth: width).padding(margin) }) {
                Image(decorative: picture, scale: 2)
            } else {
                titleLabel(maxWidth: width).padding(margin)
            }
        }
        .frame(width: size.width, alignment: .top)
        .modifier(Unsqueezed(model: model, anchor: .top))   // not squeezed with the grid
        .padding(.top, 4 + Self.inset - margin)
        .opacity(shown && model.settled ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: shown && model.settled)
    }

    private func titleLabel(maxWidth: CGFloat) -> some View {
        Text(verbatim: card.caption)
            .font(Font(NSFont.menuBarFont(ofSize: 0)))
            .foregroundStyle(AppAccent.ink)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(AppAccent.color).shadow(color: .black.opacity(0.45), radius: 3, y: 1))
            .frame(maxWidth: maxWidth)
    }

    private static func fill(hover: Bool) -> Color { AppAccent.color.opacity(hover ? 1 : 0.85) }

    /// Keeps a part that fades mounted until its fade has run out: mounted while `shown`, taken away `fade` after it was hidden (a show meanwhile cancels that), so that the
    /// cards that do not show it have nothing of it in the grid.
    private func keep(_ shown: Bool, for fade: TimeInterval, set: (Bool) -> Void) async {
        guard !shown else { return set(true) }
        try? await Task.sleep(for: .seconds(fade))
        if !Task.isCancelled { set(false) }
    }

    /// The buttons of the card under the pointer, as the cards of the island's row have them; only that card has them (and one whose buttons are fading out).
    private var buttons: some View {
        ZStack {
            if buttonsShown || buttonsMounted {
                buttonsDrawn
                    .transition(.opacity)
                    .task(id: buttonsShown) { await keep(buttonsShown, for: 0.12) { buttonsMounted = $0 } }
                    .onDisappear { hoveredButton = nil }
            }
        }
        .animation(.easeOut(duration: 0.12), value: buttonsShown)
    }

    private var buttonsDrawn: some View {
        ZStack(alignment: .topLeading) {
            ForEach(IslandCardAction.rects(in: size, among: card.actions), id: \.action) { item in
                Image(systemName: item.action.symbol).resizable().scaledToFit().fontWeight(.bold).foregroundStyle(AppAccent.ink)
                    .frame(width: item.rect.width * 0.5, height: item.rect.height * 0.5)
                    .frame(width: item.rect.width, height: item.rect.height)
                    .background(Circle().fill(Self.fill(hover: hoveredButton == .card(item.action, card.id))).shadow(color: .black.opacity(0.45), radius: 3, y: 1))
                    .contentShape(Circle())
                    .onHover { hoveredButton = $0 ? .card(item.action, card.id) : (hoveredButton == .card(item.action, card.id) ? nil : hoveredButton) }
                    .onTapGesture { model.onPerform(item.action, card) }
                    .offset(x: item.rect.minX + (item.action == .remove ? -Self.inset : Self.inset), y: item.rect.minY + Self.inset)
            }
            let rect = IslandCardAction.selectRect(in: size)
            ZStack {
                Circle().fill(Self.fill(hover: hoveredButton == .select(card.id))).shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(AppAccent.ink)
                    .frame(width: rect.width * 0.5, height: rect.height * 0.5)
                    .scaleEffect(card.selected ? 1 : 0.3).opacity(card.selected ? 1 : 0)
            }
            .frame(width: rect.width, height: rect.height)
            .contentShape(Circle())
            .onHover { hoveredButton = $0 ? .select(card.id) : (hoveredButton == .select(card.id) ? nil : hoveredButton) }
            .onTapGesture { model.onToggleStart(card) }
            .offset(x: rect.minX - Self.inset, y: rect.minY + Self.inset)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(Unsqueezed(model: model, anchor: .top))   // not squeezed with the grid: the buttons stand in the top row
        .opacity(buttonsShown ? 1 : 0)
    }
}
