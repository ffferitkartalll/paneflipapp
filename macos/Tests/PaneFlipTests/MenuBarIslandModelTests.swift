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
        XCTAssertEqual(model.openSize, CGSize(width: max(32 * 5 + 24, model.cornerRowWidth), height: 52 + 16 * 5 + 12), "the row of buttons, the picture and the room round it")
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
        XCTAssertEqual(model.cardsFit, 176, "never past the display, less the room beside the island; the picture is the least")
        let extra = 7 * card.width - 176
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
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.windowsHeight, 80 + 12 + 16)
        XCTAssertEqual(model.openSize.height, 52 + 80 + 12 + 108 + 12, "the gaps are half the height of the menu bar, the title as far from the frame as from the lower edge")
        XCTAssertEqual(model.openSize.width, max(32 * 5 + 24, model.cornerRowWidth), "one card is not wider than the picture")
    }

    func testThePanelIsTallEnoughForTheLargestZone() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 1000, height: 500))
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.tallestOpenHeight, model.openSize.height + 2 * MenuBarIslandModel.noticeButtonHeight + 2 * model.windowsGap, "and for the two lines of a notice at its foot")
    }

    func testTheCornerButtonsStandAtTheTwoEdgesOfTheIslandInTheRowAboveThePicture() {
        let model = model()
        XCTAssertEqual(model.cornerButtonsOpacity, 0, "not while the island is closed")
        model.expanded = true
        model.contentOpacity = 1
        XCTAssertEqual(model.cornerButtonsOpacity, 1)
        XCTAssertEqual(model.topHeight, 52, "the buttons with the room above and below them")
        let half = model.openSize.width / 2 - model.sideRoom
        let first = model.cornerButtonCentre(.editLayout), last = model.cornerButtonCentre(.quit)
        XCTAssertEqual(first.x - model.cornerButtonWidth(.editLayout) / 2, -half, accuracy: 0.001, "the first begins at the room of the left side")
        XCTAssertEqual(last.x + model.cornerButtonWidth(.quit) / 2, half, accuracy: 0.001, "the last ends at the room of the right side")
        XCTAssertEqual(last.y, model.topHeight / 2)
        let step = model.cornerGap
        XCTAssertEqual(model.cornerButtonCentre(.openApps).x - model.cornerButtonWidth(.openApps) / 2 - (first.x + model.cornerButtonWidth(.editLayout) / 2), step, accuracy: 0.001)
        XCTAssertEqual(last.x - model.cornerButtonWidth(.quit) / 2 - (model.cornerButtonCentre(.settings).x + model.cornerButtonWidth(.settings) / 2), step, accuracy: 0.001)
    }

    func testTheRowOfButtonsLeavesTheNotchItsWidthAndTheRoomOfTheIslandOnBothSides() {
        let model = model()
        let plain = model.cornerRowWidth
        model.notchWidth = 200
        XCTAssertGreaterThan(model.cornerRowWidth, plain + 200 - 1, "the notch lies between the two groups")
        let wide = IslandCornerAction.allCases.map { model.cornerButtonWidth($0) }
        let groups = max(wide[0] + wide[1] + model.cornerGap, wide[2] + wide[3] + model.cornerGap)
        XCTAssertEqual(model.cornerRowWidth, 2 * groups + 200 + 2 * model.sideRoom + 2 * model.sideRoom, accuracy: 0.001)
    }

    func testTheEditingNoticeGrowsByALineWhenAZoneEdgeWasMoved() {
        let model = model()
        model.notice = AttributedString("Zone edge editing is on.")
        model.noticeEditing = true
        let one = model.openSize.height
        model.noticeUndo = true
        XCTAssertEqual(model.openSize.height, one + MenuBarIslandModel.noticeButtonHeight + model.windowsGap)
        model.noticeEditing = false
        XCTAssertEqual(model.openSize.height, one, "only the editing notice has the second line")
    }

    func testANoticeIsOneLineUnderTheBarAndAtTheFootOfTheIslandOnceThePointerOpensIt() {
        let model = model()
        model.notice = AttributedString("Done")
        let line = model.noticeRowWidth + 2 * model.windowsGap
        XCTAssertEqual(model.openSize.width, max(line, 32 + 48), "no wider than the closed island unless the line needs more")
        XCTAssertEqual(model.openSize.height, 20 + 12 + 28 + 12, "the picture, a gap, the line and a gap")
        model.expanded = true
        XCTAssertEqual(model.noticeTop, 52 + 16 * 5 + 12, "under the picture")
        XCTAssertEqual(model.openSize.height, model.noticeTop + 28 + 12)
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.noticeTop, 52 + 80 + 12, "and still there with a row of cards, which lies under it")
        XCTAssertEqual(model.windowsTop, model.noticeTop + 28 + 12)
        XCTAssertEqual(model.openSize.height, model.windowsTop + 108 + 12)    }

    func testTheIslandForChoosingAZoneHasNoRowOfButtonsWhereThereIsNoNotch() {
        let model = model()
        model.expanded = true
        model.contentOpacity = 1
        XCTAssertEqual(model.topHeight, 52)
        model.pick(model.glyph.cells[0].id)
        XCTAssertEqual(model.topHeight, model.windowsGap, "only the room above the picture")
        XCTAssertEqual(model.cornerButtonsOpacity, 0)
        model.endPick()
        XCTAssertEqual(model.topHeight, model.windowsGap, "and not while it closes")
        model.openedByPointer()
        XCTAssertEqual(model.topHeight, 52, "the pointer opens it with its row again")
        model.pick(model.glyph.cells[0].id)
        model.notchWidth = 200
        XCTAssertEqual(model.topHeight, 52, "a notch hides the middle of the top: the island keeps its row")
        XCTAssertEqual(model.cornerButtonsOpacity, 0, "but it shows no buttons in it")
        model.openedByPointer()
        model.startChoosing()   // a window dragged onto the island
        XCTAssertEqual(model.cornerButtonsOpacity, 0)
        XCTAssertEqual(model.topHeight, 52)
    }

    func testAZoneWithNoWindowHasNoRoomForATitleUnderItsCard() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        model.windows = []
        XCTAssertEqual(model.windowsHeight, 80, "the card alone")
        XCTAssertEqual(model.openSize.height, 52 + 80 + 12 + 80 + 12)
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.windowsHeight, 80 + 12 + 16)
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
