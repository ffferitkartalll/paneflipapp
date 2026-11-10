import AppKit
import SwiftUI

/// A window's card in a zone's grown notch: the app's picture and the window's name (`IslandWindow.caption`), in the type of the date and the time of
/// the menu bar; dimmer for an app that is not open, dark (`ink`) where it stands on the lit card. A name cut short ends in "…".
struct ZoneCardLabel: View {
    let card: IslandWindow
    let ink: Color?

    /// The type of the date and the time of the menu bar, as the island writes the titles of its cards.
    static let font = NSFont.menuBarFont(ofSize: 0)
    /// The app's picture: so large that the glyph in it (which fills only a share of it) is as tall as a line of the name.
    static let icon = ((font.ascender - font.descender) / IconFont.glyphShare).rounded(), spacing: CGFloat = 6, padding: CGFloat = 12

    /// The Dock's badge as the compact row draws it, left of the picture: how tall it is, and how wide.
    static let badgeHeight: CGFloat = 16
    static func badgeWidth(of card: IslandWindow) -> CGFloat { card.badgeText.map { max(badgeHeight, CGFloat($0.count) * 5 + 4) } ?? 0 }
    /// What the badge takes of the card: its width and the gap to the picture (the picture's gap to the title).
    static func badgeRoom(of card: IslandWindow) -> CGFloat { card.badgeText == nil ? 0 : badgeWidth(of: card) + spacing }

    /// How wide a card is beside its name: the room at its two ends, the badge and the app's picture.
    static func chrome(of card: IslandWindow) -> CGFloat { 2 * padding + badgeRoom(of: card) + (card.glyph == nil ? 0 : icon + spacing) }

    /// How wide the card is with its whole name.
    static func width(of card: IslandWindow) -> CGFloat {
        chrome(of: card) + (card.caption as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
    }

    var body: some View {
        let open = card.windowID != nil
        HStack(spacing: Self.spacing) {
            if let glyph = card.glyph {
                Image(nsImage: glyph).renderingMode(.template).resizable().interpolation(.high).antialiased(true).scaledToFit().frame(width: Self.icon, height: Self.icon)
            }
            Text(verbatim: card.caption).font(Font(Self.font)).lineLimit(1)
        }
        .foregroundStyle(ink.map { AnyShapeStyle($0.opacity(open ? 1 : 0.5)) } ?? AnyShapeStyle(open ? .secondary : .tertiary))
        .padding(.horizontal, Self.padding)
    }
}
