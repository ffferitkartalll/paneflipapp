import PaneFlipCore
import SwiftUI

/// The menu's scene switcher: one picker listing the scenes, the one in use ticked.
struct MenuScenes: View {
    let scenes: SceneRepository
    let manager: SceneManaging

    var body: some View {
        let all = scenes.scenes
        Picker(selection: Binding(get: { scenes.activeScene.id }, set: { manager.select(id: $0) })) {
            ForEach(all) { Text(verbatim: $0.title(in: all)).tag($0.id) }
        } label: {
            Text("Scene")
        }
        .pickerStyle(.inline)
        Divider()
    }
}
