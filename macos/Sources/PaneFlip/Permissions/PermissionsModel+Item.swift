import Foundation
import Observation

extension PermissionsModel {
    struct Item: Identifiable {
        let permission: Permission
        var granted: Bool
        var id: Permission { permission }
    }
}
