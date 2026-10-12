import XCTest
@testable import PaneFlipCore

final class TabNamingTests: XCTestCase {
    func testSingleWindowShowsAppName() {
        XCTAssertEqual(TabNaming.displayNames(for: [.init(appName: "Editor", title: "Notes")]), ["Editor"])
    }

    func testSeveralWindowsOfOneAppAddTheTitle() {
        let names = TabNaming.displayNames(for: [
            .init(appName: "Browser", title: "Docs"), .init(appName: "Browser", title: "Search"), .init(appName: "Editor", title: "Notes"),
        ])
        XCTAssertEqual(names, ["Browser | Docs", "Browser | Search", "Editor"])
    }

    func testTheAppNameEndingOfATitleIsLeftOut() {
        let names = TabNaming.displayNames(for: [
            .init(appName: "Browser", title: "Docs - Browser"),
            .init(appName: "Browser", title: "Search \u{2014} Browser"),
        ])
        XCTAssertEqual(names, ["Browser | Docs", "Browser | Search"])
    }

    func testATitleThatIsOnlyTheAppNameStaysTheAppName() {
        let names = TabNaming.displayNames(for: [
            .init(appName: "Browser", title: "Page - Browser"), .init(appName: "Browser", title: "Browser"),
        ])
        XCTAssertEqual(names, ["Browser | Page", "Browser"])
    }

    func testANameInTheMiddleOfATitleStays() {
        XCTAssertEqual(TabNaming.withoutAppName("About Browser features", appName: "Browser"), "About Browser features")
    }
}
