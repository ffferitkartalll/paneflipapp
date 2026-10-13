import XCTest
@testable import PaneFlipCore

final class AppSettingsTests: XCTestCase {
    final class Storage: SettingsStorage {
        var saved: SettingsValues?
        func load() -> SettingsValues { saved ?? SettingsValues() }
        func save(_ values: SettingsValues) { saved = values }
    }

    func testChangesPersistAndFeatureSwitchesNotify() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        var placementNotified = 0
        settings.onPlacementChanged = { placementNotified += 1 }
        settings.values.placementEnabled = false
        settings.values.gap = 12
        XCTAssertEqual(placementNotified, 1)
        XCTAssertEqual(storage.saved?.gap, 12)
        XCTAssertEqual(storage.saved?.placementEnabled, false)
    }

    func testBrandIconsAreFetchedUnlessSwitchedOff() {
        XCTAssertTrue(AppSettings(storage: Storage()).values.fetchBrandIcons)
    }

    func testTheHideKeyDefaultsToLeftShiftAndPersists() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.values.hidePillKey, .leftShift)
        settings.values.hidePillKey = SnapTrigger(keys: [.init(code: 61, name: "Right Option")])
        XCTAssertEqual(storage.saved?.hidePillKey.keys.first?.code, 61)
    }

    func testTheLanguageFollowsTheSystemUnlessChosen() {
        XCTAssertEqual(AppSettings(storage: Storage()).values.language, SettingsValues.systemLanguage)
    }

    func testStoredValuesFromOlderLimitsAreBroughtIntoRange() {
        let storage = Storage()
        var old = SettingsValues()
        old.gap = 100
        old.minZoneSize = 100
        storage.saved = old
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.values.gap, 80)
        XCTAssertEqual(settings.values.minZoneSize, 240)
    }

    func testValuesSnapToTheStepGrid() {
        XCTAssertEqual(AppSettings.snapped(250, to: 240...320, step: 4), 252)
        XCTAssertEqual(AppSettings.snapped(321, to: 240...320, step: 4), 320)
    }
}
