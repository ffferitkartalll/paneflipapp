import AppKit
import SwiftUI

/// The windows of the zone chosen in the picture, as a carousel like the one inside the zone: the window in front fills a frame as large as the zone, in
/// the middle under the picture, drawn as the frame of the screen is in the picture; the other windows lie against it, side by side with no gap, outlined
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
            // Under each card: its title, and why an app is not open; they are laid out as the cards are and move with them.
            IslandShiftedRow(model: model, size: size, content: HStack(spacing: 0) { ForEach(model.windows) { caption($0).frame(width: size.width, height: model.captionHeight) } })
                .frame(width: model.glyph.size.width * model.openZoom, height: model.captionHeight)
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
                .frame(height: 16)
            Group {
                if let absence = window.absence { Text(absence.title) } else { Text(verbatim: " ") }
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))
            .frame(height: 14)
        }
        .lineLimit(1)
    }

    private func carousel(size: CGSize) -> some View {
        let wide = model.glyph.size.width * model.openZoom
        let icon = min(32, max(14, min(size.width, size.height) * 0.4))
        let frame = RoundedRectangle(cornerRadius: 3)
        func row(_ cell: @escaping (IslandWindow) -> AnyView) -> some View {
            IslandShiftedRow(model: model, size: size, content: HStack(spacing: 0) { ForEach(model.windows) { cell($0).frame(width: size.width, height: size.height) } })
                .frame(width: wide, height: size.height)
        }
        func picture(_ window: IslandWindow, _ ink: Color) -> AnyView {
            AnyView(Group {
                if let glyph = window.glyph {
                    Image(nsImage: glyph).renderingMode(.template).resizable().scaledToFit().foregroundStyle(window.windowID == nil ? ink.opacity(0.5) : ink).frame(width: icon, height: icon)
                }
            })
        }
        return ZStack {
            frame.fill(AppAccent.color).frame(width: size.width, height: size.height)
            // Outside the frame: the outlines of the windows beyond it, and the pictures, light.
            ZStack {
                row { _ in AnyView(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 2.5]))) }
                row { picture($0, .white.opacity(0.9)) }
            }
            .mask { ZStack { Rectangle(); frame.frame(width: size.width, height: size.height).blendMode(.destinationOut) }.compositingGroup() }
            // Inside it: the pictures, dark.
            row { picture($0, AppAccent.ink) }
                .mask { frame.frame(width: size.width, height: size.height) }
            frame.strokeBorder(.white.opacity(0.5), lineWidth: 1).frame(width: size.width, height: size.height)
        }
        .frame(width: wide, height: size.height)
    }
}
