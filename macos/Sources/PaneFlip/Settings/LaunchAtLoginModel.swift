import Foundation
import Observation

/// The state behind the "Launch at login" switch. The system is the source of truth, so the status is read back
/// after every change and whenever the tab appears (the user may also change it in System Settings).
@Observable
final class LaunchAtLoginModel {
    private(set) var status: LoginItemStatus
    private(set) var errorMessage: String?

    @ObservationIgnored private let loginItem: LoginItemControlling

    init(loginItem: LoginItemControlling) {
        self.loginItem = loginItem
        status = loginItem.status
    }

    var isOn: Bool { status != .disabled }

    func setOn(_ on: Bool) {
        do {
            try loginItem.setEnabled(on)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        status = loginItem.status
    }

    func refresh() { status = loginItem.status }
}
