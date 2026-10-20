import AppKit
import PaneFlipCore
import SwiftUI

/// The apps of one layout: for each zone, the apps that open in it and the order the pill shows them in.
struct LayoutAppsView: View {
    let layout: NamedLayout
    let editor: LayoutAppsEditing
    /// The zone to scroll to and frame; a new request shows it again, also while the sheet is open.
    let focus: OrderingTarget?
    /// Chosen by the layout card, which knows the screen: the default zone and how to change it.
    /// Whether the zones beyond the screen's edges are in use.
    let showsOverflow: Bool
    let defaultZone: UUID?
    let setDefaultZone: (UUID) -> Void
    let setStartApp: (_ bundleID: String, _ chosen: Bool) -> Void
    let setZoneName: (_ zone: UUID, _ name: String) -> Void
    @Environment(\.dismiss) private var dismiss
    /// The zone whose apps are framed for a moment after the sheet opened on it.
    @State private var highlighted: UUID?
    @State private var highlightRequest: UUID?
    /// The zone being renamed, and the name typed so far.
    @State private var renamingZone: UUID?
    @State private var zoneNameDraft = ""

    /// Every zone, in the order across the strip: beyond the left edge, the screen, beyond the right edge.
    private var zones: [UUID] { showsOverflow ? layout.strip.zoneIDs : layout.root.leafIDs }
    /// The zones a default can be: those of the screen (the others are out of sight).
    private var screenZones: [UUID] { layout.root.leafIDs }
    private func name(_ zone: UUID) -> String { ZoneLabel.text(of: zone, in: layout.strip) }
    /// "Zone 1", with the name the user gave it after a dot.
    private func title(_ zone: UUID) -> Text {
        let number = Text("Zone \(name(zone))")
        return layout.zoneNames[zone].map { number + Text(verbatim: " · \($0)") } ?? number
    }

    var body: some View {
        let entries = editor.entries(inZones: zones)
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: layout.name).font(.title3.bold())
            Text("An app opens in the zone you choose for it. Apps of a zone appear in the pill in the order shown here; drag them by the handle to change it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Picker("Default zone", selection: Binding(get: { defaultZone ?? screenZones.first ?? UUID() },
                                                          set: { setDefaultZone($0) })) {
                    ForEach(screenZones, id: \.self) { zone in
                        title(zone).tag(zone)
                    }
                }
                .fixedSize()
                Text("Apps of a screen that is unplugged are placed here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
            Form {
                ForEach(zones, id: \.self) { zone in
                    Section {
                        ZoneAppsList(entries: entries.filter { $0.zoneID == zone }, zones: zones, title: title, editor: editor, startApps: layout.startApps, setStartApp: setStartApp)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                    .padding(-6)
                                    .opacity(highlighted == zone ? 1 : 0)
                            }
                        addMenu(to: zone)
                    } header: {
                        HStack(spacing: 6) {
                            title(zone)
                            Button {
                                zoneNameDraft = layout.zoneNames[zone] ?? ""
                                renamingZone = zone
                            } label: { Image(systemName: "pencil") }
                                .buttonStyle(.borderless)
                                .help("Rename Zone")
                        }
                    }
                    .id(zone)
                }
            }
            .formStyle(.grouped)
            // The grouped form insets its cards by about 20 pt on each side: the sheet's own padding is enough, so the cards line
            // up with the text above them.
            .padding(.horizontal, -20)
            .alert("Rename Zone", isPresented: Binding(get: { renamingZone != nil }, set: { if !$0 { renamingZone = nil } })) {
                TextField("Zone name", text: $zoneNameDraft)
                Button("Rename") { if let zone = renamingZone { setZoneName(zone, zoneNameDraft) } }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { reveal(focus, proxy) }
            .onChange(of: focus) { _, new in reveal(new, proxy) }
            }
            HStack {
                Button { editor.open(apps: editor.startApps(of: layout)) } label: {
                    Label("Open selected apps", systemImage: "play")
                }
                .disabled(editor.startApps(of: layout).isEmpty)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 520)
    }

    private func reveal(_ target: OrderingTarget?, _ proxy: ScrollViewProxy) {
        guard let target, let zone = target.zoneID else { return }
        highlighted = zone
        highlightRequest = target.request
        DispatchQueue.main.async { withAnimation { proxy.scrollTo(zone, anchor: .top) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if highlightRequest == target.request { withAnimation { highlighted = nil } }
        }
    }

    private func addMenu(to zone: UUID) -> some View {
        Menu("Add app") {
            ForEach(editor.runningApps(), id: \.bundleID) { app in
                Button { editor.addApp(bundleID: app.bundleID, to: zone) } label: { Text(verbatim: app.name) }
            }
            Divider()
            Button("Other…") { chooseApp(for: zone) }
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Any installed app, not only the running ones.
    private func chooseApp(for zone: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        editor.addApp(bundleID: id, to: zone)
    }
}

/// The apps of one zone: each can be opened to show its windows. Apps and windows are reordered by their handles.
private struct ZoneAppsList: View {
    let entries: [LayoutAppEntry]
    let zones: [UUID]
    let title: (UUID) -> Text
    let editor: LayoutAppsEditing
    let startApps: Set<String>
    let setStartApp: (String, Bool) -> Void

    static let appHeight: CGFloat = 44
    static let windowHeight: CGFloat = 34
    @State private var opened: Set<String> = []

    var body: some View {
        ReorderableStack(items: entries, height: height, space: "zoneApps") { from, to in
            editor.reorder(app: entries[from].bundleID, in: entries[from].zoneID, by: to - from, inZones: zones)
        } row: { entry, isCarried, drag, drop in
            LayoutAppRow(entry: entry, zones: zones, title: title, editor: editor, isChosen: binding(for: entry), isCarried: isCarried, isOpen: opened.contains(entry.id),
                         toggle: { toggle(entry.id) }, drag: drag, drop: drop)
                .frame(height: height(entry), alignment: .top)
                .overlay(alignment: .bottom) { if entry.id != entries.last?.id { Divider() } }
        }
    }

    private func binding(for entry: LayoutAppEntry) -> Binding<Bool> {
        Binding(get: { startApps.contains(entry.bundleID) }, set: { setStartApp(entry.bundleID, $0) })
    }

    private func height(_ entry: LayoutAppEntry) -> CGFloat {
        opened.contains(entry.id) && entry.windows.count > 1
            ? Self.appHeight + CGFloat(entry.windows.count) * Self.windowHeight + 6
            : Self.appHeight
    }

    private func toggle(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if opened.contains(id) { opened.remove(id) } else { opened.insert(id) }
        }
    }
}

/// Rows of known heights that are reordered by a handle: the carried row follows the pointer, the rows it passes
/// move out of its way (animated), and `move` is told the new place when it is let go.
private struct ReorderableStack<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let height: (Item) -> CGFloat
    /// A name of the coordinate space, unique among nested stacks.
    let space: String
    let move: (_ from: Int, _ to: Int) -> Void
    @ViewBuilder let row: (_ item: Item, _ isCarried: Bool, _ drag: @escaping (CGFloat) -> Void,
                           _ drop: @escaping () -> Void) -> Row

    @State private var carried: Item.ID?
    @State private var travel: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isCarried = carried == item.id
                row(item, isCarried, { carry(item.id, by: $0) }, { drop() })
                    .background(isCarried ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
                    .shadow(color: .black.opacity(isCarried ? 0.3 : 0), radius: 6, y: 2)
                    .offset(y: offset(of: index))
                    .zIndex(isCarried ? 1 : 0)
                    .animation(isCarried ? nil : .snappy(duration: 0.2), value: target)
            }
        }
        .coordinateSpace(name: space)
    }

    private var heights: [CGFloat] { items.map(height) }
    private var from: Int? { items.firstIndex { $0.id == carried } }

    private func top(_ index: Int) -> CGFloat { heights[..<index].reduce(0, +) }

    /// How far the carried row may travel without leaving the stack.
    private var limited: CGFloat {
        guard let from else { return 0 }
        return ReorderPlace.limited(travel, heights: heights, from: from)
    }

    /// The place the carried row would be dropped in.
    private var target: Int {
        guard let from else { return 0 }
        return ReorderPlace.target(heights: heights, from: from, travel: travel)
    }

    private func offset(of index: Int) -> CGFloat {
        guard let from else { return 0 }
        let h = heights
        if index == from { return limited }
        if from < target, index > from, index <= target { return -h[from] }
        if target < from, index >= target, index < from { return h[from] }
        return 0
    }

    private func carry(_ id: Item.ID, by translation: CGFloat) {
        if carried != id {
            carried = id
            NSCursor.closedHand.push()
        }
        travel = translation
    }

    private func drop() {
        guard let from else { return }
        NSCursor.pop()
        let to = target
        // The row settles into its place; then the order is saved and the rows are built anew.
        let others = heights.enumerated().filter { $0.offset != from }.map(\.element)
        let settled = others[..<to].reduce(0, +) - top(from)
        withAnimation(.snappy(duration: 0.2)) { travel = settled }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            carried = nil
            travel = 0
            if to != from { move(from, to) }
        }
    }
}

/// One app of a zone: handle, glyph, name, its windows (opened under it), zone and removal controls.
private struct LayoutAppRow: View {
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
                // The same one-colour glyph as on the pill.
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
                Button(role: .destructive) { editor.remove(app: entry.bundleID, in: entry.zoneID, inZones: zones) } label: {
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

    /// The windows of the app, in the order the pill shows them, reordered the same way as the apps.
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
