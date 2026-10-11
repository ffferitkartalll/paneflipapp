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
        XCTAssertEqual(names, ["Browser — Docs", "Browser — Search", "Editor"])
    }
}
