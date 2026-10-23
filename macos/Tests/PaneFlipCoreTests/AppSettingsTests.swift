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

    func testTheWheelButtonMovesThroughWindowsUnlessSwitchedOff() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        XCTAssertTrue(settings.values.mouseButtonSwipe)
        settings.values.mouseButtonSwipe = false
        XCTAssertEqual(storage.saved?.mouseButtonSwipe, false)
    }

    func testBrandIconsAreFetchedUnlessSwitchedOff() {
        XCTAssertTrue(AppSettings(storage: Storage()).values.fetchBrandIcons)
    }

    func testTheHideKeyDefaultsToLeftCommandAndPersists() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.values.hidePillKey, .leftCommand)
        settings.values.hidePillKey = SnapTrigger(keys: [.init(code: 61, name: "Right Option")])
        XCTAssertEqual(storage.saved?.hidePillKey.keys.first?.code, 61)
    }

    func testTheLanguageFollowsTheSystemUnlessChosen() {
        XCTAssertEqual(AppSettings(storage: Storage()).values.language, SettingsValues.systemLanguage)
    }

    func testALanguageChangeIsKnownAgainstTheOneTheAppStartedWith() {
        let storage = Storage()
        var stored = SettingsValues()
        stored.language = "en"
        storage.saved = stored
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.launchLanguage, "en")
        settings.values.language = SettingsValues.systemLanguage
        XCTAssertEqual(settings.launchLanguage, "en")
        XCTAssertNotEqual(settings.values.language, settings.launchLanguage)
    }

    func testThePillIsNotShownForASingleWindowUnlessAsked() {
        XCTAssertFalse(AppSettings(storage: Storage()).values.pillForSingleWindow)
    }

    func testScrollingThroughTheWindowsNeedsLeftOptionAndLeftControlUnlessChanged() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.values.windowScrollKeys.keys.map(\.code), [58, 59])
        settings.values.windowScrollKeys = .leftCommand
        XCTAssertEqual(storage.saved?.windowScrollKeys, .leftCommand)
    }

    func testSlidingToTheZonesBeyondTheEdgesNeedsTheModifiersOfTheKeyboardShortcutUnlessChanged() {
        let keys = AppSettings(storage: Storage()).values.stripScrollKeys.keys.map(\.code)
        XCTAssertEqual(keys, [55, 58, 59], "Command, Option and Control")
    }

    func testTheTrackpadSpeedIsTwoByDefaultAndKeptInItsRange() {
        XCTAssertEqual(AppSettings(storage: Storage()).values.trackpadSpeed, 2)
        let storage = Storage()
        var old = SettingsValues()
        old.trackpadSpeed = 40
        storage.saved = old
        XCTAssertEqual(AppSettings(storage: storage).values.trackpadSpeed, 8)
    }

    func testThePillSitsAlongTheTopUnlessAsked() {
        let storage = Storage()
        let settings = AppSettings(storage: storage)
        XCTAssertEqual(settings.values.pillPosition, .top)
        settings.values.pillPosition = .bottom
        XCTAssertEqual(storage.saved?.pillPosition, .bottom)
        XCTAssertEqual(settings.values.trackpadMethod, .keysAndTwoFingers, "the keys and two fingers until the user asks for three and four")
        settings.values.trackpadMethod = .threeAndFourFingers
        XCTAssertEqual(storage.saved?.trackpadMethod, .threeAndFourFingers)
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
