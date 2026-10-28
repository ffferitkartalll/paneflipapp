import Foundation
import Observation

/// Which tab the Settings window shows, and how to open it.
@Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
    /// The Apps sheet to show (a layout and optionally a zone to scroll to); nil when none is shown. Changing it
    /// switches an open sheet to the other layout.
    var ordering: OrderingTarget?
}
