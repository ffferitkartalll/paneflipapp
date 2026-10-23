import XCTest
import PaneFlipCore

/// The layout editor's model: the strip as screens, the view that rests at one of them, and what moves it.
final class EditorModelTests: XCTestCase {
    private func model(_ strip: StripLayout = StripLayout(root: .leaf(UUID())), overflow: Bool = true) -> EditorModel {
        EditorModel(strip: strip, allowsOverflow: overflow, onApply: { _ in }, onClose: {})
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

    func testResetGoesBackToTheScreenAlone() {
        let editor = model()
        editor.addLeading(); editor.addTrailing()
        editor.reset()
        XCTAssertEqual(editor.offset, 0)
        XCTAssertEqual(editor.strip.areaRests, [0])
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
        for ratio in [0.45, 0.4, 0.35, 0.3] { editor.setRatio(line, ratio) }
        editor.endResize()
        editor.setRatio(line, 0.6)   // a second drag
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
        editor.addTrailing()
        editor.useShape(LayoutPreset.all[1])   // three columns
        XCTAssertEqual(editor.strip.root.leafIDs.count, 3)
        XCTAssertEqual(editor.strip.root.leafIDs.first, a, "the first zone keeps its stack")
        XCTAssertEqual(editor.strip.trailing.count, 1, "the areas beyond stay")
        XCTAssertEqual(editor.offset, 0)
        editor.undo()
        XCTAssertEqual(editor.strip.root.leafIDs, [a])
    }
}
