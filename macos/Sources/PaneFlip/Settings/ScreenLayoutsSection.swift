import PaneFlipCore
import SwiftUI
import UniformTypeIdentifiers

/// One screen: its name and size, then its layouts as cards and the card for adding another.
struct ScreenLayoutsSection: View {
    let screen: ScreenInfo
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    let apps: LayoutAppsEditing
    let navigation: SettingsNavigation
    let showsOverflow: Bool
    let defaultGap: Double
    @State private var choosesShape = false
    @State private var importing = false
    @State private var importFailed = false

    var body: some View {
        Section {
            ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    let activeID = repository.activeLayout(for: screen.key)?.id
                    ForEach(repository.layouts(for: screen.key)) { layout in
                        LayoutCard(screen: screen, layout: layout, isActive: layout.id == activeID,
                                   isTaken: repository.isTaken(layout: layout.id, key: screen.key),
                                   layouts: layouts, editor: editor, apps: apps, navigation: navigation, showsOverflow: showsOverflow, defaultGap: defaultGap)
                            .id(layout.id)
                    }
                    addCard
                }
                .fixedSize(horizontal: false, vertical: true)   // the row is as tall as its tallest card
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .task(id: navigation.ordering) {
                if let id = navigation.ordering?.layoutID { proxy.scrollTo(id, anchor: .center) }
            }
            }
            if screen.desktopCount > 1 { desktopPickers }
        } header: {
            HStack {
                Label(screen.name, systemImage: "display")
                Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))").foregroundStyle(.secondary)
                Spacer()
                // With several desktops the current one is told by its number; with one there is nothing to tell apart.
                Group {
                    if screen.desktopCount > 1, let number = screen.desktopNumber { Text("Desktop \(number)") } else { Text("Current desktop") }
                }
                .foregroundStyle(.secondary)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let layout = try? NamedLayout.imported(from: data) {
                layouts.importLayout(for: screen.key, layout)
            } else {
                importFailed = true
            }
        }
        .alert("This file is not a layout.", isPresented: $importFailed) { Button("Done") {} }
    }

    private func halfCard(_ icon: String, _ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22, weight: .regular))
                Text(title).font(.headline)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// Which layout each desktop of the display uses; a layout is offered to one desktop at a time.
    private var desktopPickers: some View {
        ForEach(1...max(screen.desktopCount, 1), id: \.self) { number in
            let key = "\(screen.displayID)|d\(number)"
            Picker("Desktop \(number)", selection: Binding(
                get: { repository.activeLayout(for: key)?.id },
                set: { if let id = $0 { layouts.activate(key: key, id: id) } else { layouts.deactivate(key: key) } })) {
                Text("No layout").tag(UUID?.none)
                ForEach(repository.layouts(for: key).filter { !repository.isTaken(layout: $0.id, key: key) }) { layout in
                    Text(verbatim: layout.name).tag(Optional(layout.id))
                }
            }
        }
    }

    /// Built like a layout preview and exactly as large as a whole layout card (preview, name row, buttons).
    /// The size comes from an invisible real card, so it is the same with or without layouts, for any screen shape.
    private var addCard: some View {
        ZStack {
            LayoutCard(screen: screen, layout: NamedLayout(name: "Layout", root: .leaf(UUID())), isActive: false,
                       layouts: layouts, editor: editor, apps: apps, navigation: navigation, showsOverflow: showsOverflow, defaultGap: defaultGap)
                .hidden()

            // The card in two halves: Add on top, Import below.
            VStack(spacing: 6) {
                halfCard("plus", "Add") { choosesShape = true }
                halfCard("square.and.arrow.down", "Import") { importing = true }
            }
            .sheet(isPresented: $choosesShape) {
                LayoutPresetSheet(screen: screen) { preset, edit in
                    let layout = layouts.addLayout(for: screen.key, preset: preset)
                    if edit { editor.edit(on: screen, layoutID: layout.id) }
                }
            }
        }
        .frame(width: LayoutCard.width)
    }
}
