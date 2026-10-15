import SwiftUI

/// The menu bar icon. It lives as long as the app, so it hands the Settings scene's opener to the navigation:
/// SwiftUI wants the Settings scene opened through its own action, which only a view can read.
struct MenuBarLabel: View {
    let navigation: SettingsNavigation
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image("MenuBarIcon")
            .onAppear { navigation.openSettings = { openSettings() } }
    }
}
