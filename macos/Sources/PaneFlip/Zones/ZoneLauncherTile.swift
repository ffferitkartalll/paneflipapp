import SwiftUI

/// An app of the launcher: its glyph above its name; a press opens it.
struct ZoneLauncherTile: View {
    let app: LauncherApp
    let glyph: NSImage
    /// The badge at the glyph's top left while the pointer is on the tile: a minus takes the app out of the stack, a plus puts it in.
    let removes: Bool
    let carrying: Bool
    /// This is the app that was taken: its badge stays and goes with it.
    let isMoving: Bool
    let badge: () -> Void
    @State private var hovered = false
    private let lineHeight = NSFont.preferredFont(forTextStyle: .body).boundingRectForFont.height.rounded(.up)

    var body: some View {
    // Not a Button: a button takes the press and the drag of the view round it (the placed apps are carried) never starts.
    VStack(spacing: 8) {
            Image(nsImage: glyph).renderingMode(.template).resizable().interpolation(.high).antialiased(true).scaledToFit()
                .frame(width: 44, height: 44)
            // Two lines of room for every name, so one-line and two-line names leave the glyphs on the same line.
            Text(verbatim: app.name).lineLimit(2).truncationMode(.tail).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 2 * lineHeight, maxHeight: 2 * lineHeight, alignment: .top)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .hoverHighlight(radius: 10)
        .overlay(alignment: .topLeading) {
            if isMoving || (hovered && !carrying) {
                Button(action: badge) {
                    Image(systemName: removes ? "minus.circle.fill" : "plus.circle.fill").font(.title3).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, removes ? Color.red : AppAccent.color)
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isMoving || (hovered && !carrying))
    }
}
