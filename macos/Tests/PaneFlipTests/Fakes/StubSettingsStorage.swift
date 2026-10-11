import PaneFlipCore

final class StubSettingsStorage: SettingsStorage {
    var saved = SettingsValues()

    func load() -> SettingsValues { saved }
    func save(_ values: SettingsValues) { saved = values }
}
