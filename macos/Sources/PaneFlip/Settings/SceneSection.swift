import PaneFlipCore
import SwiftUI

/// One scene: its name and buttons (Activate, Edit, Remove), then for each display the layout it uses.
struct SceneSection: View {
    let scene: DisplayScene
    /// The last scene carries the button that adds one, below its panel, so that it moves with the form when the tab is pulled past its end.
    let isLast: Bool
    let scenes: [DisplayScene]
    let isActive: Bool
    /// The displays now connected, one entry each.
    let screens: [ScreenInfo]
    /// Where the displays stand on the desk.
    let arrangement: DeskArrangement
    let repository: LayoutRepository
    let manager: SceneManaging
    let apps: LayoutAppsEditing

    private static let spacing: CGFloat = 16

    @State private var isEditing = false
    @State private var confirmingRemoval = false
    @State private var offeringReset = false

    private var isDefault: Bool { scenes.first?.id == scene.id }
    private var title: String { scene.title(in: scenes) }

    var body: some View {
        Section {
            // The displays side by side, as large as on the desk map less the room between them, so that the row never needs to scroll and the pictures keep the
            // sizes they have to one another there.
            HStack(alignment: .top, spacing: Self.spacing) {
                ForEach(screens) { screen in
                    let chosen = layouts(of: screen)
                    let shrink = (DeskScale.mapWidth - Self.spacing * CGFloat(screens.count - 1)) / DeskScale.mapWidth
                    SceneLayoutPicker(screen: screen, pictureWidth: DeskScale.width(of: screen, among: screens), shownWidth: DeskScale.width(of: screen, among: screens) * shrink,
                                      layouts: chosen.all, selected: chosen.used?.id,
                                      inUse: !isActive ? [] : Set(chosen.all.map(\.id).filter { repository.activeLayout(for: screen.key)?.id == $0 || repository.isTaken(layout: $0, key: screen.key) }), apps: apps.editing(scene: scene.id)) {
                        manager.setLayout(sceneID: scene.id, display: screen.displayID, layoutID: $0)
                    }
                }
            }
            .padding(.vertical, 2)
        } header: {
            header
        } footer: {
            if isLast {
                HStack {
                    Spacer()
                    Button { manager.addScene() } label: { Image(systemName: "plus").font(.body).frame(width: 24, height: 24).contentShape(.rect) }
                        .buttonStyle(.plain)
                        .hoverHighlight(radius: 6)
                        .help("Add scene")
                        .accessibilityLabel("Add scene")
                }
                .padding(.trailing, -10)   // a footer is inset; the button's edge lies on the panel's
            }
        }
        .sheet(isPresented: $isEditing) {
            SceneEditSheet(scene: scene, scenes: scenes, screens: screens, arrangement: arrangement, isDefault: isDefault, manager: manager) { layouts(of: $0).used }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(verbatim: title).font(.headline)
            Spacer()
            if isActive {
                Button("Active") {}.buttonStyle(.borderedProminent).allowsHitTesting(false)
            } else {
                Button("Activate") { manager.select(id: scene.id) }.buttonStyle(.bordered).hoverHighlight()
            }
            Button("Edit") { isEditing = true }
                .buttonStyle(.bordered)
                .hoverHighlight()
            Button("Remove") { if isDefault { offeringReset = true } else { confirmingRemoval = true } }
                .buttonStyle(.bordered)
                .hoverHighlight()
                .alert("The default scene cannot be removed. Reset it instead?", isPresented: $offeringReset) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) { manager.reset(id: scene.id) }
                }
                .confirmationDialog("Remove this scene?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) { manager.remove(id: scene.id) }
                    Button("Cancel", role: .cancel) {}
                }
        }
        .controlSize(.small)
        .textCase(nil)
    }

    /// The layouts of a display and the one this scene uses on it: the one it names, else the first.
    private func layouts(of screen: ScreenInfo) -> (all: [NamedLayout], used: NamedLayout?) {
        let all = repository.layouts(for: screen.key)
        return (all, all.first { $0.id == scene.layouts[screen.displayID] } ?? all.first)
    }
}
