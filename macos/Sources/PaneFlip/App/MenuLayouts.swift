import PaneFlipCore
import SwiftUI

/// The menu's layout switcher: one picker per screen listing its layouts, the active one ticked. Screens with a single
/// layout have nothing to switch and are left out.
struct MenuLayouts: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let screens: ScreenProviding

    var body: some View {
        let switchable = screens.screens().filter { repository.layouts(for: $0.key).count > 1 }
        ForEach(switchable) { screen in
            Picker(selection: Binding(
                get: { repository.activeLayout(for: screen.key)?.id },
                set: { if let id = $0 { layouts.activate(key: screen.key, id: id) } })) {
                ForEach(repository.layouts(for: screen.key)) { layout in
                    Text(verbatim: layout.name).tag(Optional(layout.id))
                }
            } label: {
                Text(verbatim: screen.name)
            }
            .pickerStyle(.inline)
        }
        if !switchable.isEmpty { Divider() }
    }
}
