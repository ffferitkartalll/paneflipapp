import AppKit

/// Decides what happens at launch: if every permission is already granted the app starts at once, otherwise the
/// permission screen is shown and the app starts when the user continues.
final class AppLauncher {
    private let permissions: PermissionChecking
    private let screen: PermissionsWindowController
    private let startServices: () -> Void
    private var isAskingAgain = false

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

    /// The permission was switched off while the app runs: ask for it again. The services keep running (and work
    /// again by themselves once it is back), so continuing only closes the screen.
    func recoverPermissions() {
        let model = PermissionsModel(checker: permissions)
        guard !isAskingAgain, !model.allGranted else { return }
        isAskingAgain = true
        model.startPolling()
        screen.show(model: model) { [weak self] in
            model.stopPolling()
            self?.isAskingAgain = false
        }
    }
}
