import Foundation
import Observation

/// Which tab the Settings window shows, and how to open it.
@Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
}
