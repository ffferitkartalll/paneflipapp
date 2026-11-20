import PaneFlipCore
import SwiftUI

/// The sheet of a scene: its name, the layouts of its displays with their zones as the island shows them, one zone chosen, and below them the layouts of the other
/// displays, in which the zone that the windows of the chosen one go to when its display is unplugged is chosen.
struct SceneEditSheet: View {
    let scene: DisplayScene
    let scenes: [DisplayScene]
    let screens: [ScreenInfo]
    /// Where the displays stand on the desk.
    let arrangement: DeskArrangement
    let isDefault: Bool
    let manager: SceneManaging
    /// The layout the scene uses on a display.
    let usedLayout: (ScreenInfo) -> NamedLayout?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modalRoom) private var room
    @State private var draftName = ""
    @State private var sourceZone: UUID?
    /// The height of the content, once it is laid out.
    @State private var measuredHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    /// All the room there is: the whole content area of the window it opens over.
    private var size: CGSize { room }

    /// A display with the layout the scene uses on it.
    private typealias Display = (screen: ScreenInfo, layout: NamedLayout)
    /// The zone being set, with its display and layout.
    private typealias Source = (zone: UUID, screen: ScreenInfo, layout: NamedLayout)

    /// The content and the buttons under it: this sheet is as tall as its content, down past the bottom of the window it opens over, and no taller than the display has room for
    /// (the whole of that until the content is measured); it scrolls beyond that.
    private var height: CGFloat {
        let most = max((NSScreen.main?.visibleFrame.height ?? 900) - 160, 300)
        return measuredHeight > 0 && footerHeight > 0 ? min(measuredHeight + footerHeight, most) : most
    }

    var body: some View {
        // Asked once for the whole body: the displays and their layouts.
        let displays: [Display] = screens.compactMap { screen in usedLayout(screen).map { (screen, $0) } }
        let source = self.source(in: displays)
        let scale = deskScale(of: displays)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !isDefault {
                        TextField(text: $draftName, prompt: Text(verbatim: scene.defaultTitle(in: scenes))) { Text("Rename Scene") }
                            .padding(12)
                            .background(.quaternary, in: .rect(cornerRadius: 10))
                    }
                    if let source {
                        section("Select the zone whose windows move when its display is unplugged") {
                            panels(of: displays, scale: scale, pick: { display in
                                (display.layout.strip.zoneIDs.contains(source.zone) ? source.zone : nil, { sourceZone = $0 })
                            }, trailing: { _ in EmptyView() })
                        }
                        let others = displays.filter { $0.screen.displayID != source.screen.displayID }
                        if !others.isEmpty {
                            arrow
                            section("Select the zone the windows of the chosen zone move to") {
                                panels(of: others, scale: scale, pick: { display in
                                    (effective(source, on: display, among: others), { save(ordered(others, for: source), among: others, for: source, choosing: (display.screen.displayID, $0)) })
                                }, trailing: { if others.count > 1 { numbers(of: $0, among: others, source: source) } })   // one display has no order
                            }
                        }
                    }
                }
                .padding([.horizontal, .top], 20)   // the buttons below have the room under the panels
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredHeight = $0 }
            }
            HStack {
                Spacer()
                Button("Automatic") { if let source { manager.setMoves(sceneID: scene.id, zone: source.zone, to: []) } }
                    .hoverHighlight()
                Button("Done") {
                    if !isDefault { manager.rename(id: scene.id, to: draftName.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
        .frame(width: size.width, height: height)   // as tall as its content, up to the room there is
        .onAppear { draftName = scene.name }
    }

    // MARK: Panels

    /// A panel with its title above it, inset from the panel as a section's title is.
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(.secondary).padding(.leading, 10)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 10))
        }
    }

    /// One panel for each display: its name above with `trailing` at its right end, and in it the layout with all its zones, `lit` of which is lit and a click on any of which is `choose`n.
    private func panels<Trailing: View>(of displays: [Display], scale: CGFloat, pick: @escaping (Display) -> (lit: UUID?, choose: (UUID) -> Void),
                                        @ViewBuilder trailing: @escaping (Display) -> Trailing) -> some View {
        VStack(spacing: 10) {
            ForEach(displays, id: \.screen.displayID) { display in
                let behaviour = pick(display)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(verbatim: display.screen.name).padding(.leading, 10)   // inset from the panel below as a section's title is from its panel
                        Spacer()
                        trailing(display)
                    }
                    panel(of: display, scale: scale, lit: behaviour.lit, choose: behaviour.choose)
                }
            }
        }
    }

    /// A display's layout with all its zones in a card.
    private func panel(of display: Display, scale: CGFloat, lit: UUID?, choose: @escaping (UUID) -> Void) -> some View {
        ZoneGlyphView(strip: display.layout.strip, screenSize: display.screen.size, zone: lit, screenWidth: display.screen.deskSize.width * scale, onSelect: choose)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private var arrow: some View {
        Image(systemName: "arrow.down").font(.title3).foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }

    /// How much a display's size on the desk is drawn magnified in the panels: the display that is widest there (its zones beyond the edges too) fills the whole width, and
    /// the others keep their sizes to it. 
    private func deskScale(of displays: [Display]) -> CGFloat {
        let widest = displays.map { CGFloat($0.layout.strip.totalWidth) * $0.screen.deskSize.width }.max() ?? 0
        // The pictures lie in the content (20 pt of padding), in a panel (12 pt) and a card (10 pt), and 2 pt of their drawing lie outside them.
        // The width is the sheet's, not measured: a picture wider than the room would widen what is measured, and that the picture, without end.
        let content = size.width - 40
        return widest > 0 ? max(content - 2 * (12 + 10) - 4, 0) / widest : 1
    }

    // MARK: Zones

    /// The zone being set: the one chosen, else the first of the first display.
    private func source(in displays: [Display]) -> Source? {
        if let zone = sourceZone, let found = displays.first(where: { $0.layout.strip.zoneIDs.contains(zone) }) { return (zone, found.screen, found.layout) }
        return displays.first.flatMap { first in first.layout.root.leafIDs.first.map { ($0, first.screen, first.layout) } }
    }

    /// Where the zone goes by itself, by where the displays stand on the desk: the displays nearest first (`order`, indices of `shown`) and the zone of each that has it.
    private func placement(_ source: Source, among shown: [Display]) -> (order: [Int], zones: [UUID: (target: Int, zone: UUID)]) {
        let all = shown + [(source.screen, source.layout)]
        let frames = arrangement.frames(of: all.sorted { $0.screen.cocoaFrame.minX < $1.screen.cocoaFrame.minX }.map { (id: $0.screen.displayID, size: $0.screen.deskSize) })
        return SceneMoves.onDesk(from: (frames[source.screen.displayID] ?? .zero, source.layout),
                                 onto: shown.map { (frame: frames[$0.screen.displayID] ?? .zero, layout: $0.layout) })
    }

    /// The zone of a display that the windows of the chosen one go to as it is shown: the one chosen for it, else the one they go to by themselves if that is on this
    /// display, else the one the layouts lay them in.
    private func effective(_ source: Source, on display: Display, among shown: [Display]) -> UUID? {
        if let named = explicit(source.zone, on: display) { return named }
        if let at = shown.firstIndex(where: { $0.screen.displayID == display.screen.displayID }), let placed = placement(source, among: shown).zones[source.zone], placed.target == at { return placed.zone }
        return layoutsZone(source, on: display)
    }

    /// The zone the layouts lay the windows of the chosen zone in on a display.
    private func layoutsZone(_ source: Source, on display: Display) -> UUID? {
        SceneMoves.automatic(from: source.layout, to: display.layout)[source.zone]
    }

    /// The zone of the display that the scene names for the zone, if it does.
    private func explicit(_ zone: UUID, on display: Display) -> UUID? {
        let zones = display.layout.strip.zoneIDs
        return scene.moves[zone]?.first { zones.contains($0) }
    }

    // MARK: Order

    /// The displays in the order the windows try them as it is shown: those the scene names a zone of, in the order it lists them, then the others, the nearest on the desk first.
    private func ordered(_ displays: [Display], for source: Source) -> [Display] {
        let list = scene.moves[source.zone] ?? []
        let near = placement(source, among: displays).order
        func place(_ index: Int) -> (Int, Int) {
            (explicit(source.zone, on: displays[index]).flatMap(list.firstIndex(of:)) ?? .max, near.firstIndex(of: index) ?? .max)
        }
        return displays.indices.sorted { place($0) < place($1) }.map { displays[$0] }
    }

    /// Saves the zones of the displays in the order given, each as it is shown now, in the places of the zones the scene names now (the names of displays that are not connected
    /// keep theirs). `choosing` is a click on a zone of a display: a click on the zone chosen already goes back to the one the layouts lay the windows in.
    private func save(_ order: [Display], among shown: [Display], for source: Source, choosing: (display: String, zone: UUID)? = nil) {
        var zones = order.compactMap { display -> UUID? in
            let shownNow = effective(source, on: display, among: shown)
            guard let choosing, choosing.display == display.screen.displayID else { return shownNow }
            return explicit(source.zone, on: display) == choosing.zone ? layoutsZone(source, on: display) : choosing.zone
        }.makeIterator()
        let zonesOf = Set(order.flatMap { $0.layout.strip.zoneIDs })
        var list: [UUID] = []
        for named in scene.moves[source.zone] ?? [] {
            if !zonesOf.contains(named) { list.append(named) } else if let next = zones.next() { list.append(next) }
        }
        while let next = zones.next() { list.append(next) }
        manager.setMoves(sceneID: scene.id, zone: source.zone, to: list)
    }

    /// The numbers 1 to the count of the displays at the right of a display's name: the one lit is its place in the order; another puts the display there, and the display
    /// that was there takes its place.
    private func numbers(of display: Display, among shown: [Display], source: Source) -> some View {
        let order = ordered(shown, for: source)
        let place = order.firstIndex { $0.screen.displayID == display.screen.displayID } ?? 0
        return HStack(spacing: 4) {
            ForEach(0..<min(shown.count, 9), id: \.self) { index in
                let chosen = index == place
                Button {
                    var swapped = order
                    swapped.swapAt(place, index)
                    save(swapped, among: shown, for: source)
                } label: {
                    Text(verbatim: "\(index + 1)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(chosen ? AppAccent.ink : Color.primary)
                        .frame(width: 22, height: 22)
                        .background(chosen ? AnyShapeStyle(AppAccent.color) : AnyShapeStyle(.quaternary), in: .rect(cornerRadius: 5))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .hoverHighlight(radius: 5)
            }
        }
        .help("Try order")
    }
}
