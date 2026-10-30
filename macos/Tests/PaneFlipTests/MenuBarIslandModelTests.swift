import XCTest
import CoreGraphics
import PaneFlipCore

/// The size of the open island with the frame of the windows of a zone under its picture.
final class MenuBarIslandModelTests: XCTestCase {
    private func model() -> MenuBarIslandModel {
        let model = MenuBarIslandModel()
        model.barHeight = 24
        model.openZoom = 5
        model.glyph = ZoneGlyph(zones: [(UUID(), CGRect(x: 0, y: 0, width: 1000, height: 500))], screen: CGRect(x: 0, y: 0, width: 1000, height: 500),
                                screenSize: CGSize(width: 32, height: 16))
        return model
    }

    private func choose(_ model: MenuBarIslandModel, rect: CGRect) {
        let id = UUID()
        model.glyph = ZoneGlyph(zones: [(id, rect)], screen: CGRect(x: 0, y: 0, width: 1000, height: 500), screenSize: CGSize(width: 32, height: 16))
        model.windowsZone = id
    }

    func testWithNoZoneChosenThereIsNoRowAndTheIslandIsAsTallAsItsPicture() {
        let model = model()
        XCTAssertEqual(model.windowsHeight, 0)
        XCTAssertEqual(model.openSize, CGSize(width: 32 * 5 + 48, height: 24 + 16 * 5 + 24), "the picture and the height of the menu bar round it")
    }

    private func cards(_ count: Int, front: Int) -> [IslandWindow] {
        (0 ..< count).map { IslandWindow(windowID: CGWindowID($0 + 1), bundleID: "b", name: "w", glyph: nil, glyphRevision: 0, absence: nil, isActive: $0 == front) }
    }

    /// A card: as tall as the screen in the picture is (16 × 5), 16:9.
    private let card = CGSize(width: 80.0 * 16 / 9, height: 80)

    func testTheIslandGrowsFromThePictureToTheWidthEveryCardNeedsAndNoFurtherThanTheDisplay() {
        let model = model()
        model.displayWidth = 2000
        choose(model, rect: CGRect(x: 0, y: 0, width: 250, height: 250))   // the size of the zone does not count
        XCTAssertEqual(model.windowsFrame.width, card.width, accuracy: 0.001)
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.cardsFit, 160, "a card or two: the picture is wide enough")
        model.windows = cards(7, front: 3)
        XCTAssertEqual(model.cardsFit, 7 * card.width, accuracy: 0.001, "seven cards")
        model.windows = cards(7, front: 0)
        XCTAssertEqual(model.cardsFit, 7 * card.width, accuracy: 0.001, "whichever is in front")
        XCTAssertEqual(model.frameShift, -3 * card.width, accuracy: 0.001, "the frame is on the first card: three cards left of the middle")
        model.displayWidth = 200
        XCTAssertEqual(model.cardsFit, 160, "never past the display, less the room beside the island; the picture is the least")
        let extra = 7 * card.width - 160
        XCTAssertEqual(model.rowShift, extra / 2, accuracy: 0.001, "the row is wider than its room: it is moved to bring the first card into view, as far as its end allows")
        XCTAssertEqual(model.frameShift, -3 * card.width + extra / 2, accuracy: 0.001)
    }

    func testTheCardsAreSixteenByNineAndAsTallAsTheScreenInThePictureWhateverTheZone() {
        let model = model()
        for rect in [CGRect(x: 0, y: 0, width: 500, height: 250), CGRect(x: 0, y: 0, width: 1000, height: 500), CGRect(x: 0, y: 0, width: 100, height: 400)] {
            choose(model, rect: rect)
            XCTAssertEqual(model.windowsFrame.height, card.height, accuracy: 0.001)
            XCTAssertEqual(model.windowsFrame.width, card.width, accuracy: 0.001)
        }
    }

    func testAChosenZoneAddsTheGapTheFrameAndTheTitleToTheHeight() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        XCTAssertEqual(model.windowsHeight, 80 + 12 + 30)
        XCTAssertEqual(model.openSize.height, 24 + 80 + 12 + 122 + 12, "the gaps are half the height of the menu bar, the title as far from the frame as from the lower edge")
        XCTAssertEqual(model.openSize.width, 32 * 5 + 48, "one card is not wider than the picture")
    }

    func testThePanelIsTallEnoughForTheLargestZone() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 1000, height: 500))
        XCTAssertEqual(model.tallestOpenHeight, model.openSize.height + MenuBarIslandModel.noticeButtonHeight + model.windowsGap, "and for the line of a notice at its foot")
    }

    func testANoticeIsOneLineUnderTheBarAndAtTheFootOfTheIslandOnceThePointerOpensIt() {
        let model = model()
        model.notice = AttributedString("Done")
        let line = model.noticeRowWidth + 2 * model.windowsGap
        XCTAssertEqual(model.openSize.width, max(line, 32 + 48), "no wider than the closed island unless the line needs more")
        XCTAssertEqual(model.openSize.height, 24 + 12 + 22 + 12, "the bar, a gap, the line and a gap")
        model.expanded = true
        XCTAssertEqual(model.noticeTop, 24 + 16 * 5 + 12, "under the picture")
        XCTAssertEqual(model.openSize.height, model.noticeTop + 22 + 12)
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        XCTAssertEqual(model.noticeTop, 24 + 80 + 12, "and still there with a row of cards, which lies under it")
        XCTAssertEqual(model.windowsTop, model.noticeTop + 22 + 12)
        XCTAssertEqual(model.openSize.height, model.windowsTop + 122 + 12)    }

    func testWindowsShownAloneLieUnderTheLineOfANotice() {
        let model = model()
        model.displayWidth = 1000
        model.notice = AttributedString("Done")
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        model.windows = cards(2, front: 0)
        let noticeOnly = model.openSize.height
        model.peeking = true
        XCTAssertEqual(model.windowsTop, 24 + 12 + 22 + 12)
        XCTAssertEqual(model.openSize.height, noticeOnly + 122 + 12, "the row of cards under the line")
    }

    func testClosingTheRowTakesBackTheHeight() {
        let model = model()
        let closed = model.openSize
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        XCTAssertGreaterThan(model.openSize.height, closed.height)
        model.windowsZone = nil
        XCTAssertEqual(model.openSize, closed)
    }
}
