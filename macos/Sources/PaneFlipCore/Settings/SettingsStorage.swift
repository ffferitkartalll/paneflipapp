import Foundation

/// Port for persisting the settings; the app adapts it onto UserDefaults.
public protocol SettingsStorage {
    func load() -> SettingsValues
    func save(_ values: SettingsValues)
}
