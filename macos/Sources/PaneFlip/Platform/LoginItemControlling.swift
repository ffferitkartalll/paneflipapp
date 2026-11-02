import Foundation

/// Registering and unregistering the app as a login item.
protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
}
