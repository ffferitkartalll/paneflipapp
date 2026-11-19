import XCTest
@testable import PaneFlipCore

final class WindowSearchTests: XCTestCase {
    private func titles(_ query: String, in all: [String], others: [String] = []) -> [String] {
        WindowSearch.matches(query, in: all, others: others).map { all[$0] }
    }

    func testATitleThatBeginsWithTheTextComesBeforeOneThatOnlyHasItInside() {
        XCTAssertEqual(titles("st", in: ["Updatest", "Strongbox"]), ["Strongbox", "Updatest"])
    }

    func testTheBestKindOfMatchComesFirst() {
        // the whole title, its beginning, a word of it, inside a word
        XCTAssertEqual(titles("chat", in: ["Archatype", "Google Chat", "Chat Room", "Chat"]), ["Chat", "Chat Room", "Google Chat", "Archatype"])
    }

    func testTheEarlierAWordIsFoundTheBetter() {
        XCTAssertEqual(titles("pre", in: ["Safari Technology Preview", "Preview"]), ["Preview", "Safari Technology Preview"])
        XCTAssertEqual(titles("ter", in: ["Hello Terminal World", "Terminal"]), ["Terminal", "Hello Terminal World"])
    }

    func testTheWordsOfTheTextMayComeInAnyOrderAndAnywhere() {
        XCTAssertEqual(titles("chr goo", in: ["Chrome", "Google Chrome", "Google"]), ["Google Chrome"])
    }

    func testEqualMatchesKeepTheShorterTitleFirstThenTheirOrder() {
        XCTAssertEqual(titles("a", in: ["Alpha beta", "Alp", "Alp", "Al"]), ["Al", "Alp", "Alp", "Alpha beta"])
    }

    func testCaseAccentsAndTheTurkishIDoNotMatter() {
        XCTAssertEqual(titles("CAFE", in: ["Café notes"]), ["Café notes"])
        XCTAssertEqual(titles("istanbul", in: ["İstanbul", "ISTANBUL", "ıstanbul"]), ["İstanbul", "ISTANBUL", "ıstanbul"])
        XCTAssertEqual(titles("Itunes", in: ["iTunes"]), ["iTunes"])
        XCTAssertEqual(titles("sis", in: ["Şişli"]), ["Şişli"])
    }

    func testTheNameOfTheAppFindsAWindowWhoseTitleLacksItButAfterTheTitlesThatHaveIt() {
        let all = ["Inbox", "Mail notes"]
        XCTAssertEqual(titles("mail", in: all, others: ["Mail", "Notes"]), ["Mail notes", "Inbox"])
        XCTAssertEqual(titles("mail inbox", in: all, others: ["Mail", "Notes"]), ["Inbox"])
    }

    func testNothingMatchesAnEmptyOrBlankTextOrATextNoTitleContains() {
        XCTAssertEqual(WindowSearch.matches("", in: ["Safari"]), [])
        XCTAssertEqual(WindowSearch.matches("   ", in: ["Safari"]), [])
        XCTAssertEqual(WindowSearch.matches("xyz", in: ["Safari"]), [])
    }
}
