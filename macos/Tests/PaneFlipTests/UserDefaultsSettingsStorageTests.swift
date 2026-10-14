import XCTest
import PaneFlipCore

final class UserDefaultsSettingsStorageTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var storage: UserDefaultsSettingsStorage!

    override func setUp() {
        suite = "paneflip.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        storage = UserDefaultsSettingsStorage(defaults: defaults)
    }

    func testSavingOtherSettingsKeepsTheLanguageTheSystemHolds() {
        defaults.set(["tr"], forKey: "AppleLanguages")   // chosen in System Settings
        var values = SettingsValues()
        values.gap = 12
        storage.save(values)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["tr"])
    }

    func testChoosingALanguageAndGoingBackToTheSystemOne() {
        var values = SettingsValues()
        values.language = "en"
        storage.save(values)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["en"])
        values.language = SettingsValues.systemLanguage
        storage.save(values)
        // Read from the app's own domain: a plain read falls through to the system's languages.
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
    }
}
