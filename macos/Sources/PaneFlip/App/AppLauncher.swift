import AppKit

/// Decides what happens at launch: if every permission is already granted the app starts at once, otherwise the
/// permission screen is shown and the app starts when the user continues.
final class AppLauncher {
    private let permissions: PermissionChecking
    private let screen: PermissionsWindowController
    private let startServices: () -> Void

    init(permissions: PermissionChecking, screen: PermissionsWindowController, startServices: @escaping () -> Void) {
        self.permissions = permissions
        self.screen = screen
        self.startServices = startServices
    }

    func launch() {
        NSApp.setActivationPolicy(.accessory)
        let model = PermissionsModel(checker: permissions)
        guard !model.allGranted else { return startServices() }

        model.startPolling()
        screen.show(model: model) { [startServices] in
            model.stopPolling()
            startServices()
        }
    }
}
