import PaneFlipCore
import SwiftUI

/// The apps whose windows PaneFlip never touches: a list with the + and − bar below it, as in the system's own settings.
struct IgnoredAppsSection: View {
    @Bindable var settings: AppSettings
    let catalog: AppCatalog
    let editor: LayoutAppsEditing
    @State private var selected: String?

    var body: some View {
        Section {
            Text("PaneFlip leaves the windows of these apps alone: they are never placed in a zone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                list
                Divider()
                bar
            }
            .background(.background, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.separator) }
            .clipShape(.rect(cornerRadius: 8))
        } header: {
            Text("Ignored apps")
        }
    }

    private var list: some View {
        List(selection: $selected) {
            ForEach(settings.values.ignoredApps, id: \.self) { id in
                HStack(spacing: 10) {
                    Image(nsImage: editor.glyph(ofApp: id))
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: 22, height: 22)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: catalog.name(bundleID: id) ?? id)
                        Text(verbatim: id).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .tag(id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .scrollContentBackground(.hidden)
        .frame(height: 190)
        .overlay {
            if settings.values.ignoredApps.isEmpty {
                Image(systemName: "app.dashed").font(.system(size: 34)).foregroundStyle(.quaternary)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            Menu {
                ForEach(catalog.regularApps().filter { !$0.bundleID.isEmpty && !settings.values.ignoredApps.contains($0.bundleID) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, id: \.bundleID) { app in
                    Button { add(app.bundleID) } label: { Text(verbatim: app.name) }
                }
                Divider()
                Button("Other…", action: chooseApp)
            } label: {
                Image(systemName: "plus").frame(width: 30, height: 26)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add app")
            .accessibilityLabel("Add app")

            Divider().frame(height: 16)

            Button(action: removeSelected) { Image(systemName: "minus").frame(width: 30, height: 26) }
                .buttonStyle(.borderless)
                .disabled(selected == nil)
                .help("Remove")
                .accessibilityLabel("Remove")

            Spacer()
        }
        .padding(.horizontal, 4)
        .background(.quaternary.opacity(0.4))
    }

    private func add(_ bundleID: String) {
        if !settings.values.ignoredApps.contains(bundleID) { settings.values.ignoredApps.append(bundleID) }
        selected = bundleID
    }

    private func removeSelected() {
        guard let selected else { return }
        settings.values.ignoredApps.removeAll { $0 == selected }
        self.selected = nil
    }

    /// Any installed app, not only the running ones.
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        add(id)
    }
}
