import XCTest

final class CDNBrandGlyphsTests: XCTestCase {
    func testTheWholeNameIsTriedBeforeItsFirstWord() {
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Brand Desktop"), ["branddesktop", "brand"])
    }

    func testOneWordNamesHaveOneCandidate() {
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Brand"), ["brand"])
    }

    func testAnotherProductOfTheSameWordIsNotTheBrand() {
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Vendor Browser"), ["vendorbrowser"])
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Brand Player"), ["brandplayer"])
    }

    func testPunctuationIsDropped() {
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Brand Beta"), ["brandbeta", "brand"])
        XCTAssertEqual(CDNBrandGlyphs.slugs(forApp: "Foo-Bar!"), ["foobar"])
    }
}
