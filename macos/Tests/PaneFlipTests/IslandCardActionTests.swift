import XCTest
import CoreGraphics

final class IslandCardActionTests: XCTestCase {
    func testTheButtonsStandInTheTopCornersOfTheCardWithoutTouchingEachOther() {
        for width in [60, 120, 400] as [CGFloat] {
            let card = CGSize(width: width, height: 90)
            let rects = IslandCardAction.rects(in: card)
            XCTAssertEqual(rects.map(\.action), [.quit, .close, .hide, .minimize, .remove])
            for item in rects { XCTAssertTrue(CGRect(origin: .zero, size: card).contains(item.rect), "inside a card \(width) wide") }
            for (a, b) in zip(rects, rects.dropFirst()) { XCTAssertLessThan(a.rect.maxX, b.rect.minX) }
            XCTAssertEqual(Set(rects.map(\.rect.minY)).count, 1)
            XCTAssertEqual(rects[0].rect.minX, rects[0].rect.minY, "the first stands in the top left corner")
            XCTAssertEqual(rects[4].rect.maxX, width - rects[4].rect.minY, "the last in the top right one")
        }
    }

    func testACardWithFewerButtonsKeepsTheirSizeAndPlaces() {
        let card = CGSize(width: 142, height: 80)
        let all = IslandCardAction.rects(in: card), two = IslandCardAction.rects(in: card, among: [.quit, .remove])
        XCTAssertEqual(two.map(\.action), [.quit, .remove])
        XCTAssertEqual(two[0].rect, all[0].rect)
        XCTAssertEqual(two[1].rect, all[4].rect)
    }

    func testWhichCardsShowWhichButtons() {
        func card(window: CGWindowID?, absence: WindowAbsence?) -> IslandWindow {
            IslandWindow(windowID: window, bundleID: "b", name: "n", glyph: nil, glyphRevision: 0, absence: absence, isActive: false)
        }
        XCTAssertEqual(card(window: 1, absence: nil).actions, IslandCardAction.allCases)
        XCTAssertEqual(card(window: nil, absence: .notRunning).actions, [.quit, .remove], "an app that has quit: open it or take it out")
        XCTAssertEqual(card(window: nil, absence: .closed).actions, [.quit, .remove])
        XCTAssertEqual(card(window: nil, absence: .hidden).actions, [])
        XCTAssertEqual(card(window: nil, absence: .minimized).actions, [])
    }
}
