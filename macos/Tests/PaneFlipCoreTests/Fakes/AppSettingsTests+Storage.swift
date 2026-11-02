import XCTest
@testable import PaneFlipCore

extension AppSettingsTests {
    final class Storage: SettingsStorage {
        var saved: SettingsValues?
        func load() -> SettingsValues { saved ?? SettingsValues() }
        func save(_ values: SettingsValues) { saved = values }
    }
}
