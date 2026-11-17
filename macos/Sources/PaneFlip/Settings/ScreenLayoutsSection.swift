import PaneFlipCore
import SwiftUI
import UniformTypeIdentifiers

/// One screen: its name and size, then its layouts as cards and the card for adding another.
struct ScreenLayoutsSection: View {
    let screen: ScreenInfo
    /// How wide the picture of a layout of this display is drawn.
    let pictureWidth: CGFloat
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let editor: LayoutEditing
    @State private var choosesShape = false
    @State private var importing = false
    @State private var importFailed = false

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    let activeID = repository.activeLayout(for: screen.key)?.id
                    let all = repository.layouts(for: screen.key)
                    ForEach(all) { layout in
                        LayoutCard(screen: screen, pictureWidth: pictureWidth, layout: layout, defaultTitle: layout.defaultTitle(in: all), isActive: layout.id == activeID,
                                   isTaken: repository.isTaken(layout: layout.id, key: screen.key),
                                   isDefault: repository.isDefault(layout: layout.id, key: screen.key),
                                   layouts: layouts, editor: editor)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)   // the row is as tall as its tallest card
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            if screen.desktopCount > 1 { desktopPickers }
        } header: {
            HStack {
                Label(screen.name, systemImage: "display")
                Text(verbatim: "\(Int(screen.size.width))×\(Int(screen.size.height))").foregroundStyle(.secondary)
                Spacer()
                // With several desktops the current one is told by its number; with one there is nothing to tell apart.
                Group {
                    if screen.desktopCount > 1, let number = screen.desktopNumber { Text("Desktop \(screen.desktopsBefore + number)") } else { Text("Current desktop") }
                }
                .foregroundStyle(.secondary)
            }
        } footer: {
            // Import to the left of Add, both at the right edge of the panel (a footer is inset a little).
            HStack(spacing: 4) {
                Spacer()
                footerButton("square.and.arrow.down", "Import") { importing = true }
                footerButton("plus", "Add") { choosesShape = true }
            }
            .padding(.trailing, -10)
        }
        .sheet(isPresented: $choosesShape) {
            LayoutPresetSheet(screen: screen, pictureWidth: pictureWidth) { preset, edit in
                let layout = layouts.addLayout(for: screen.key, preset: preset)
                if edit { editor.edit(on: screen, layoutID: layout.id) }
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

    /// Which layout each desktop of the display uses; a layout is offered to one desktop at a time.
    private var desktopPickers: some View {
        ForEach(1...max(screen.desktopCount, 1), id: \.self) { number in
            let key = "\(screen.displayID)|d\(number)"
            Picker("Desktop \(screen.desktopsBefore + number)", selection: Binding(
                get: { repository.activeLayout(for: key)?.id },
                set: { if let id = $0 { layouts.activate(key: key, id: id) } else { layouts.deactivate(key: key) } })) {
                Text("No layout").tag(UUID?.none)
                ForEach(repository.layouts(for: key).filter { !repository.isTaken(layout: $0.id, key: key) }) { layout in
                    Text(verbatim: layout.title(in: repository.layouts(for: key))).tag(Optional(layout.id))
                }
            }
        }
    }

    private func footerButton(_ icon: String, _ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.body).frame(width: 24, height: 24).contentShape(.rect) }
            .buttonStyle(.plain)
            .hoverHighlight(radius: 6)
            .help(title)
            .accessibilityLabel(title)
    }
}
