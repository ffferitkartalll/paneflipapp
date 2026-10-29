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

    func testSettingsOfRemovedFeaturesAreForgottenWhenLoading() {
        defaults.set(true, forKey: "scrollGestureEnabled")
        defaults.set(false, forKey: "edgeScrollEnabled")
        _ = storage.load()
        XCTAssertNil(defaults.object(forKey: "scrollGestureEnabled"))
        XCTAssertNil(defaults.object(forKey: "edgeScrollEnabled"))
    }

    func testTheDeskArrangementIsKept() {
        var values = SettingsValues()
        values.deskArrangement = DeskArrangement(origins: ["a": CGPoint(x: 10, y: 20)])
        storage.save(values)
        XCTAssertEqual(storage.load().deskArrangement, values.deskArrangement)
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

    func testTheZoneShortcutsOfEarlierVersionsMoveToTheNewKeysUnlessThePersonChangedThem() {
        var old = SettingsValues()
        old.zoneUpShortcut = .formerZoneUp            // never changed
        old.zoneLeftShortcut = .formerZoneLeft
        old.zoneDownShortcut = SnapTrigger(keys: [.init(code: 5, name: "G"), .init(code: 58, name: "Left Option")])   // chosen by the person
        old.zoneRightShortcut = .formerZoneRight
        storage.save(old)

        let loaded = storage.load()

        XCTAssertEqual(loaded.zoneUpShortcut, .zoneUp)
        XCTAssertEqual(loaded.zoneLeftShortcut, .zoneLeft)
        XCTAssertEqual(loaded.zoneDownShortcut, old.zoneDownShortcut)
        XCTAssertEqual(loaded.zoneRightShortcut, .zoneRight)
        XCTAssertEqual([SnapTrigger.zoneUp, .zoneLeft, .zoneDown, .zoneRight].map { $0.keys.first?.name }, ["I", "J", "K", "L"])
    }
}
