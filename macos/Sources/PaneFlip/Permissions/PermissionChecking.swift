/// Asking the system about permissions, and sending the user to grant them.
protocol PermissionChecking {
    func isGranted(_ permission: Permission) -> Bool
    /// Shows the system's own prompt (and registers the app in the permission list).
    func request(_ permission: Permission)
    func openSystemSettings(for permission: Permission)
}
