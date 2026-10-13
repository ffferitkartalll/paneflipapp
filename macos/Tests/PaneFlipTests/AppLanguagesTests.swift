import XCTest
@testable import PaneFlip

final class AppLanguagesTests: XCTestCase {
    func testTheLanguagesAreEveryTranslationSorted() {
        let languages = AppLanguages(available: ["tr", "Base", "en"], preferred: ["en-US"])
        XCTAssertEqual(languages.available, ["en", "tr"])
    }

    func testASystemLanguageWithoutTranslationIsReported() {
        XCTAssertNil(AppLanguages(available: ["en"], preferred: ["en-GB"]).unavailableSystemLanguage)
        XCTAssertNotNil(AppLanguages(available: ["en"], preferred: ["tr-TR", "en"]).unavailableSystemLanguage)
        XCTAssertNil(AppLanguages(available: ["en", "tr"], preferred: ["tr-TR"]).unavailableSystemLanguage)
    }

    func testLanguagesAreNamedInTheirOwnLanguage() {
        let languages = AppLanguages(available: ["en", "tr"], preferred: [])
        XCTAssertEqual(languages.title(of: "en"), "English")
        XCTAssertEqual(languages.title(of: "tr"), "Türkçe")
    }
}
