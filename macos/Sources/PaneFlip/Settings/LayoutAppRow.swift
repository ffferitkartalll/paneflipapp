import AppKit
import PaneFlipCore
import SwiftUI

/// One app of a zone: handle, glyph, name, its windows (opened under it), zone and removal controls.
struct LayoutAppRow: View {
    let entry: LayoutAppEntry
    let zones: [UUID]
    let title: (UUID) -> Text
    let editor: LayoutAppsEditing
    @Binding var isChosen: Bool
    let isCarried: Bool
    let isOpen: Bool
    let toggle: () -> Void
    let drag: (CGFloat) -> Void
    let drop: () -> Void
    @State private var handPushed = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                handle(drag: drag, drop: drop, space: "zoneApps")
                // The same one-colour glyph as in the island.
                if let icon = entry.icon {
                    Image(nsImage: icon).renderingMode(.template).resizable().interpolation(.high).antialiased(true)
                        .frame(width: 18, height: 18)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: entry.name)
                    if entry.windows.count > 1 {
                        Text("\(entry.windows.count) windows").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if entry.windows.count > 1 {
                    Button(action: toggle) { Image(systemName: isOpen ? "chevron.up" : "chevron.down") }
                        .help("Show the windows")
                }
                Toggle("Open selected apps", isOn: $isChosen)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help("Open selected apps")
                Menu {
                    ForEach(zones, id: \.self) { zone in
                        Button {
                            editor.move(app: entry.bundleID, from: entry.zoneID, to: zone, inZones: zones)
                        } label: { title(zone) }
                        .disabled(zone == entry.zoneID)
                    }
                } label: { Image(systemName: "rectangle.split.2x2") }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Move to another zone")
                Button { editor.remove(app: entry.bundleID, in: entry.zoneID, inZones: zones) } label: {
                    Image(systemName: "minus.circle")
                }
                .help("Remove")
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 6)   // the handle brings its own room on the left
            .frame(height: ZoneAppsList.appHeight)

            if isOpen, entry.windows.count > 1 { windows }
        }
    }

    /// The windows of the app, in the order the island shows them, reordered the same way as the apps.
    private var windows: some View {
        ReorderableStack(items: entry.windows, height: { _ in ZoneAppsList.windowHeight }, space: "windows-\(entry.id)") { from, to in
            editor.reorder(window: entry.windows[from].slot, by: to - from, inZones: zones)
        } row: { window, _, drag, drop in
            HStack(spacing: 8) {
                handle(drag: drag, drop: drop, space: "windows-\(entry.id)")
                Text(verbatim: window.title.isEmpty ? entry.name : window.title)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.leading, 26)
            .frame(height: ZoneAppsList.windowHeight)
        }
        .padding(.bottom, 6)
    }

    /// The row is picked up by its handle: an open hand over it, a closed one while it is carried.
    private func handle(drag: @escaping (CGFloat) -> Void, drop: @escaping () -> Void, space: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 30)
            .contentShape(.rect)
            .help("Drag to change the order")
            .onHover { inside in
                if inside, !handPushed {
                    NSCursor.openHand.push()
                    handPushed = true
                } else if !inside, handPushed {
                    NSCursor.pop()
                    handPushed = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                    .onChanged { drag($0.translation.height) }
                    .onEnded { _ in drop() }
            )
    }
}
