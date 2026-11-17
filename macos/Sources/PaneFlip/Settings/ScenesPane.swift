import AppKit
import PaneFlipCore
import SwiftUI

/// Tab: the scenes. Each sets the layout of every display and where the windows of a display go when it is unplugged.
struct ScenesPane: View {
    let repository: LayoutRepository
    let scenes: SceneRepository
    let manager: SceneManaging
    let screens: ScreenProviding
    let settings: AppSettings
    /// Bumped when displays are plugged in or out or desktops change, so the list of screens is read again.
    @State private var displaysChanged = 0

    var body: some View {
        let _ = displaysChanged
        let all = scenes.scenes
        let shown = screens.screens().filter { $0.desktopNumber != nil }
        Form {
            Section {
                Text("A scene sets the layout of each display and where the windows of a display go when it is unplugged.")
                    .foregroundStyle(.secondary)
            }
            ForEach(all) { scene in
                SceneSection(scene: scene, isLast: scene.id == all.last?.id, scenes: all, isActive: scene.id == scenes.activeScene.id, screens: shown, arrangement: settings.values.deskArrangement, repository: repository, manager: manager)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in displaysChanged += 1 }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in displaysChanged += 1 }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in displaysChanged += 1 }
    }
}
