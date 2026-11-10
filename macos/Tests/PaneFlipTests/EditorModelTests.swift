import XCTest
import PaneFlipCore

/// The layout editor's model: the strip as screens, the view that rests at one of them, and what moves it.
final class EditorModelTests: XCTestCase {
    private func model(_ strip: StripLayout = StripLayout(root: .leaf(UUID())), overflow: Bool = true) -> EditorModel {
        EditorModel(strip: strip, allowsOverflow: overflow, onApply: { _ in }, onClose: {})
    }

    func testTheDefaultZoneIsChosenUndoneAndFallsBackToTheFirstWhenItsZoneGoes() {
        let a = UUID(), b = UUID()
        var applied: UUID?
        let editor = EditorModel(strip: StripLayout(root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b))),
                                 onApply: { applied = $0.defaultZone }, onClose: {})
        XCTAssertEqual(editor.effectiveDefaultZone, a)
        editor.setDefaultZone(b)
        XCTAssertEqual(editor.effectiveDefaultZone, b)
        editor.undo()
        XCTAssertEqual(editor.effectiveDefaultZone, a)
        editor.redo()
        editor.apply()
        XCTAssertEqual(applied, b)
        editor.reset()   // one zone is left, with the first identity
        XCTAssertEqual(editor.effectiveDefaultZone, a)
    }

    func testAZoneKeepsItsRatioWhileALineMovesAndLosesItWhenSplit() {
        let a = UUID(), b = UUID(), c = UUID(), column = UUID()
        let rect = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        var applied: [UUID: ZoneAspect] = [:]
        let editor = EditorModel(strip: StripLayout(root: .split(id: column, sideBySide: true, ratio: 0.5, first: .leaf(a),
                                                                 second: .split(id: UUID(), sideBySide: false, ratio: 0.5, first: .leaf(b), second: .leaf(c)))),
                                 onApply: { applied = $0.aspects }, onClose: {})
        editor.setAspect(ZoneAspect(16, 9), of: b, in: rect, screen: rect, least: 100)
        editor.setRatio(column, 0.6, in: rect, screen: rect, least: 100)
        let zone = editor.root.zones(in: rect).first { $0.id == b }!.rect
        XCTAssertEqual(zone.width / zone.height, 16.0 / 9, accuracy: 0.001)
        editor.undo()
        editor.undo()
        XCTAssertNil(editor.aspects[b], "undone with the lines")
        editor.redo()
        editor.split(b, sideBySide: true, ratio: 0.5)
        XCTAssertNil(editor.aspects[b], "split, a zone is no longer at its ratio")
        editor.undo()
        editor.apply()
        XCTAssertEqual(applied, [b: ZoneAspect(16, 9)])
    }

    func testAPlusAddsAScreenAsWideAsTheScreenAndTheViewGoesToIt() {
        let editor = model()
        XCTAssertTrue(editor.canAddLeading && editor.canAddTrailing, "a lone screen has nothing on either side")
        editor.addTrailing()
        XCTAssertEqual(editor.strip.trailing.map(\.width), [1])
        XCTAssertEqual(editor.offset, 1, "the editor shows the new screen")
        XCTAssertTrue(editor.canAddTrailing, "another one may follow it")
        XCTAssertFalse(editor.canAddLeading, "the left side is a screen away")

        editor.addLeading()
        XCTAssertEqual(editor.strip.leading.map(\.width), [1])
        XCTAssertEqual(editor.offset, -1)
        editor.addLeading()
        XCTAssertEqual(editor.offset, -2, "outside the ones there are")
    }

    func testScrollingMovesTheViewFromOneScreenToTheNextAndNotPastTheEnds() {
        let editor = model()
        editor.addTrailing(); editor.addTrailing(); editor.addLeading()
        XCTAssertEqual(editor.offset, -1)

        editor.step(1)
        XCTAssertEqual(editor.offset, 0)
        editor.step(1)
        editor.step(1)
        XCTAssertEqual(editor.offset, 2)
        editor.step(1)
        XCTAssertEqual(editor.offset, 2, "nothing beyond the last screen")
        editor.step(-9)
        XCTAssertEqual(editor.offset, -1, "nor beyond the first")
    }

    func testTwoFingersMoveOneScreenForASwipeAndAWheelOneForANotch() {
        let editor = model()
        editor.addTrailing(); editor.addTrailing()   // the view is at the last of three
        editor.scrolled(horizontal: 70, finished: false)   // the content went to the right: the screen on the left
        editor.scrolled(horizontal: 300, finished: false)
        XCTAssertEqual(editor.offset, 1, "one screen for the swipe")
        editor.scrolled(horizontal: 0, finished: true)

        editor.wheel(2)   // away from you: the left
        XCTAssertEqual(editor.offset, 0)
        editor.wheel(-1)   // toward you: the right
        XCTAssertEqual(editor.offset, 1)
    }

    func testTheScreenInViewIsTheOneTheUserMayRemove() {
        let editor = model()
        XCTAssertNil(editor.editedArea, "the screen's own layout stays")
        editor.addTrailing(); editor.addTrailing()
        XCTAssertEqual(editor.editedArea?.id, editor.strip.trailing[1].id)

        editor.removeEditedArea()
        XCTAssertEqual(editor.strip.trailing.count, 1)
        XCTAssertEqual(editor.offset, 1, "the view comes to rest at the screen that is now the last")
        editor.removeEditedArea()
        XCTAssertTrue(editor.strip.trailing.isEmpty)
        XCTAssertEqual(editor.offset, 0)
        editor.removeEditedArea()   // nothing to remove on the screen itself
        XCTAssertEqual(editor.offset, 0)
    }

    func testTheEdgesOfScreensAreNotLinesToDrag() {
        let editor = model()
        editor.addTrailing()
        XCTAssertTrue(editor.isAreaLine(editor.strip.trailing[0].id))
        XCTAssertFalse(editor.isAreaLine(UUID()))
    }

    func testResetAndShapesActOnTheScreenInViewOnly() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        editor.addTrailing()
        editor.useShape(LayoutPreset.all[1])   // three columns, on the area in view
        XCTAssertEqual(editor.strip.trailing[0].root.leafIDs.count, 3)
        XCTAssertEqual(editor.strip.root.leafIDs, [a], "the screen's own layout is not touched")
        editor.reset()
        XCTAssertEqual(editor.strip.trailing[0].root.leafIDs.count, 1)
        XCTAssertEqual(editor.offset, 1, "and the view stays")
        editor.previewGrid(rows: 2, columns: 2)
        XCTAssertEqual(editor.strip.trailing[0].root.leafIDs.count, 4)
        editor.cancelGrid()
        XCTAssertEqual(editor.strip.trailing[0].root.leafIDs.count, 1)
    }

    func testAreasAddedBeforeKeepTheirWidthAndTheViewStillRestsAtTheirEdges() {
        var strip = StripLayout(root: .leaf(UUID()))
        strip.trailing = [Overflow(width: 0.25)]   // a quarter-screen area from before
        let editor = model(strip)
        editor.step(1)
        XCTAssertEqual(editor.offset, 0.25)
        editor.addTrailing()
        XCTAssertEqual(editor.offset, 1.25)
        XCTAssertEqual(editor.strip.areaRests, [0, 0.25, 1.25])
    }

    func testAZoneSizeIsItsShareOfTheAreaInPoints() {
        let area = CGSize(width: 1440, height: 900)
        XCTAssertEqual(EditorModel.size(of: CGRect(x: 0, y: 0, width: 500, height: 400), in: CGSize(width: 1000, height: 800), area: area), "720 × 450")
        XCTAssertEqual(EditorModel.size(of: CGRect(x: 0, y: 0, width: 5, height: 5), in: .zero, area: area), "", "no size yet, nothing to divide by")
    }

    func testUndoAndRedoGoBackAndForthAlongTheChanges() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        XCTAssertFalse(editor.canUndo)
        editor.split(a, sideBySide: true, ratio: 0.5)
        editor.addTrailing()
        XCTAssertEqual(editor.strip.trailing.count, 1)

        editor.undo()
        XCTAssertTrue(editor.strip.trailing.isEmpty)
        XCTAssertEqual(editor.offset, 0, "the view goes back with it")
        XCTAssertEqual(editor.root.leafIDs.count, 2, "the split is still there")
        editor.redo()
        XCTAssertEqual(editor.strip.trailing.count, 1)
        editor.undo(); editor.undo()
        XCTAssertEqual(editor.root.leafIDs, [a])
        XCTAssertFalse(editor.canUndo)
        XCTAssertTrue(editor.canRedo)
    }

    func testANewChangeEndsTheRedoes() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        editor.split(a, sideBySide: true, ratio: 0.5)
        editor.undo()
        XCTAssertTrue(editor.canRedo)
        editor.split(a, sideBySide: false, ratio: 0.5)
        XCTAssertFalse(editor.canRedo)
    }

    func testTheMovesOfOneDragAreOneChange() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        editor.split(a, sideBySide: true, ratio: 0.5)
        guard case .split(let line, _, _, _, _) = editor.root else { return XCTFail("a split") }
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 600)
        for ratio in [0.45, 0.4, 0.35, 0.3] { editor.setRatio(line, ratio, in: rect, screen: rect, least: 10) }
        editor.endResize()
        editor.setRatio(line, 0.6, in: rect, screen: rect, least: 10)   // a second drag
        editor.undo()
        guard case .split(_, _, let afterOne, _, _) = editor.root else { return XCTFail("a split") }
        XCTAssertEqual(afterOne, 0.3, accuracy: 1e-9, "the second drag is undone as a whole")
        editor.undo()
        guard case .split(_, _, let afterTwo, _, _) = editor.root else { return XCTFail("a split") }
        XCTAssertEqual(afterTwo, 0.5, accuracy: 1e-9, "and the first as a whole")
    }

    func testAShapeReplacesTheScreenLayoutAndKeepsTheOldZonesInOrder() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        editor.useShape(LayoutPreset.all[1])   // three columns
        editor.addTrailing()
        XCTAssertEqual(editor.strip.root.leafIDs.count, 3)
        XCTAssertEqual(editor.strip.root.leafIDs.first, a, "the first zone keeps its stack")
        XCTAssertEqual(editor.strip.trailing.count, 1, "the areas beyond stay")
        editor.undo(); editor.undo()
        XCTAssertEqual(editor.strip.root.leafIDs, [a])
    }

    func testTheEditorPutsTheLinesWhereTheDesktopDoes() {
        let a = UUID(), b = UUID(), c = UUID(), outer = UUID(), inner = UUID()
        let root = LayoutNode.split(id: outer, sideBySide: true, ratio: 0.25, first: .leaf(a),
                                    second: .split(id: inner, sideBySide: true, ratio: 0.5, first: .leaf(b), second: .leaf(c)))
        let editor = EditorModel(strip: StripLayout(root: root), gap: 80, onApply: { _ in }, onClose: {})
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let laid = editor.laid(in: screen, screen: screen)
        let desktop = StripGeometry(strip: editor.strip, screen: screen).zones(offset: 0, gap: 80).map { ($0.id, $0.rect) }
        for (id, rect) in desktop { XCTAssertEqual(laid.zones.first { $0.id == id }?.rect, rect, "the zones are laid as on the desktop") }
        let lines = Dictionary(uniqueKeysWithValues: laid.dividers.map { ($0.id, $0.position) })
        let zones = Dictionary(uniqueKeysWithValues: desktop)
        XCTAssertEqual(lines[inner] ?? 0, (zones[b]!.maxX + zones[c]!.minX) / 2, accuracy: 0.001, "in the middle of the gap, also inside a shrunk zone")
    }

    func testAGridPreviewFollowsTheSlidersAndIsKeptAsOneChangeOrPutBack() {
        let a = UUID()
        let editor = model(StripLayout(root: .leaf(a)))
        editor.previewGrid(rows: 2, columns: 2)
        editor.previewGrid(rows: 3, columns: 2)
        XCTAssertEqual(editor.root.leafIDs.count, 6)
        XCTAssertEqual(editor.root.leafIDs.first, a)
        editor.cancelGrid()
        XCTAssertEqual(editor.root.leafIDs, [a], "closed without Apply: as it was")
        XCTAssertFalse(editor.canUndo)

        editor.previewGrid(rows: 2, columns: 3)
        editor.applyGrid()
        editor.cancelGrid()   // closing the popover after Apply changes nothing
        XCTAssertEqual(editor.root.leafIDs.count, 6)
        editor.undo()
        XCTAssertEqual(editor.root.leafIDs, [a], "one undo step for the whole drag")
    }
}
