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
}
