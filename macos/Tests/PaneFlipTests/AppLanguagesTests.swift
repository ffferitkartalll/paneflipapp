import XCTest

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

    func testTwoTranslationsOfOneLanguageAreToldApartByRegion() {
        let languages = AppLanguages(available: ["pt", "pt-BR", "de", "nb-NO", "zh-Hans", "zh-Hant"], preferred: [])
        XCTAssertNotEqual(languages.title(of: "pt"), languages.title(of: "pt-BR"))
        XCTAssertTrue(languages.title(of: "pt").contains("Portugal"))
        XCTAssertTrue(languages.title(of: "pt-BR").contains("Brasil"))
        XCTAssertNotEqual(languages.title(of: "zh-Hans"), languages.title(of: "zh-Hant"))
        XCTAssertEqual(languages.title(of: "de"), "Deutsch")
        XCTAssertFalse(languages.title(of: "nb-NO").contains("("))
    }
}
