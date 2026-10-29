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

    func testTheIslandGrowsFromThePictureToTheWidthEveryCardNeedsAndNoFurtherThanTheDisplay() {
        let model = model()
        model.displayWidth = 1000
        choose(model, rect: CGRect(x: 0, y: 0, width: 250, height: 250))   // the frame is 40 wide
        XCTAssertEqual(model.windowsFrame.width, 40)
        model.windows = cards(1, front: 0)
        XCTAssertEqual(model.cardsFit, 160, "a card or two: the picture is wide enough")
        model.windows = cards(7, front: 3)
        XCTAssertEqual(model.cardsFit, 280, "seven cards: 7 × 40")
        model.windows = cards(7, front: 0)
        XCTAssertEqual(model.cardsFit, 280, "whichever is in front")
        XCTAssertEqual(model.frameShift, -120, "the frame is on the first card: three cards left of the middle")
        model.displayWidth = 200
        XCTAssertEqual(model.cardsFit, 160, "never past the display, less the room beside the island; the picture is the least")
        XCTAssertEqual(model.rowShift, 60, "the row is wider than its room by 120: it is moved to bring the first card into view, as far as its end allows")
        XCTAssertEqual(model.frameShift, -60, "and the frame is on the first card: 80 from the left end of the room")
    }

    func testTheFrameIsAsLargeAsTheChosenZoneInThePicture() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))   // a quarter of the screen: 16 × 8 in the picture, five times that open
        XCTAssertEqual(model.windowsFrame, CGSize(width: 80, height: 40))
    }

    func testAChosenZoneAddsTheGapTheFrameAndTheTitleToTheHeight() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 500, height: 250))
        XCTAssertEqual(model.windowsHeight, 40 + 12 + 30)
        XCTAssertEqual(model.openSize.height, 24 + 80 + 12 + 82 + 12, "the gaps are half the height of the menu bar, the title as far from the frame as from the lower edge")
        XCTAssertEqual(model.openSize.width, 32 * 5 + 48, "the frame is not wider than the picture")
    }

    func testThePanelIsTallEnoughForTheLargestZone() {
        let model = model()
        choose(model, rect: CGRect(x: 0, y: 0, width: 1000, height: 500))
        XCTAssertEqual(model.tallestOpenHeight, model.openSize.height)
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
