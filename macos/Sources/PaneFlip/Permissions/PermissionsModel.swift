import Foundation
import Observation

/// What the permission screen shows: each required permission and whether it has been granted yet.
/// Polls while visible, because the user grants permissions in System Settings, outside the app.
@Observable
final class PermissionsModel {
    struct Item: Identifiable {
        let permission: Permission
        var granted: Bool
        var id: Permission { permission }
    }

    private(set) var items: [Item]
    @ObservationIgnored private let checker: PermissionChecking
    @ObservationIgnored private var timer: Timer?

    init(checker: PermissionChecking) {
        self.checker = checker
        items = Permission.allCases.map { Item(permission: $0, granted: checker.isGranted($0)) }
    }

    var allGranted: Bool { items.allSatisfy(\.granted) }

    func refresh() {
        for i in items.indices {
            let granted = checker.isGranted(items[i].permission)
            if items[i].granted != granted { items[i].granted = granted }
        }
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func request(_ permission: Permission) { checker.request(permission) }
    func openSystemSettings(for permission: Permission) { checker.openSystemSettings(for: permission) }
}
