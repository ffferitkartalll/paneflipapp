import PaneFlipCore
import SwiftUI

/// The menu's layout switcher: one picker per screen listing the layouts its current desktop may use (those no other
/// desktop uses), the one in use ticked. A desktop with nothing to choose from is left out.
struct MenuLayouts: View {
    let repository: LayoutRepository
    let layouts: LayoutManaging
    let screens: ScreenProviding

    var body: some View {
        let choices = screens.screens().map { screen in
            (screen, repository.layouts(for: screen.key).filter { !repository.isTaken(layout: $0.id, key: screen.key) })
        }.filter { screen, free in free.count > 1 || (!free.isEmpty && repository.activeLayout(for: screen.key) == nil) }
        ForEach(choices, id: \.0.id) { screen, free in
            Picker(selection: Binding(
                get: { repository.activeLayout(for: screen.key)?.id },
                set: { if let id = $0 { layouts.activate(key: screen.key, id: id) } })) {
                ForEach(free) { layout in
                    Text(verbatim: layout.name).tag(Optional(layout.id))
                }
            } label: {
                Text(verbatim: screen.name)
            }
            .pickerStyle(.inline)
        }
        if !choices.isEmpty { Divider() }
    }
}
