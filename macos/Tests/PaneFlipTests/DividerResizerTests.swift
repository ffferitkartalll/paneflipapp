import XCTest
import CoreGraphics
import PaneFlipCore

/// The mode in which the lines between zones are moved by hand: which screen's lines it shows, what a drag changes in the layout, and how the moves are undone.
/// The handles are the real ones (small panels); the tests press, drag and let go of them through their views.
@MainActor
final class DividerResizerTests: XCTestCase {
    private let key = "display|d1"
    private let a = UUID(), b = UUID(), c = UUID()
    private var repository: LayoutRepository!
    private var layouts: FakeLayouts!
    private var screens: FakeScreens!
    private var viewport: StripViewport!
    private var resizer: DividerResizer!
    private var layoutID: UUID!
    private var shownScreens: [ScreenInfo] = []
    private var changes: [Bool] = []
    private var undoStates: [Bool] = []
    private var blocked = false

    private func screen(_ key: String) -> ScreenInfo {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        return ScreenInfo(key: key, name: "Screen", size: frame.size, cocoaFrame: frame, cocoaVisibleFrame: frame, axVisible: frame)
    }

    override func setUp() {
        repository = LayoutRepository(store: MemoryDocumentStore())
        let layout = repository.addLayout(for: key)
        layoutID = layout.id
        var strip = layout.strip
        strip.root = .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b))
        strip.trailing = [Overflow(width: 1, root: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(c), second: .leaf(UUID())))]
        repository.setStrip(strip, ofLayout: layout.id, key: key)
        let storage = StubSettingsStorage()
        var values = SettingsValues()
        values.gap = 0
        storage.saved = values
        let settings = AppSettings(storage: storage)
        viewport = StripViewport()
        screens = FakeScreens()
        screens.infos = [screen(key)]
        screens.pointerAX = CGPoint(x: 500, y: 250)
        shownScreens = screens.infos
        layouts = FakeLayouts(repository: repository)
        resizer = DividerResizer(layouts: layouts, repository: repository, planner: ZonePlanner(layouts: repository, settings: settings, viewport: viewport), screens: screens,
                                 settings: settings, viewport: viewport, keys: FakeKeys(), capsLock: CapsLockKeyState(), screensNow: { [unowned self] in shownScreens },
                                 isBlocked: { [unowned self] in blocked })
        resizer.onChange = { [unowned self] in changes.append($0) }
        resizer.onUndoChange = { [unowned self] in undoStates.append($0) }
    }

    override func tearDown() {
        resizer.finish()
    }

    private var strip: StripLayout { repository.layout(id: layoutID, key: key)!.strip }

    /// Takes the only handle, moves the pointer to `x` (the line's axis) and lets go.
    private func drag(to x: CGFloat) {
        let mouse = resizer.shownHandles[0].mouse
        screens.pointerAX = CGPoint(x: 500, y: 250)
        mouse.onPress?()
        screens.pointerAX = CGPoint(x: x, y: 250)
        mouse.onDrag?()
        mouse.onRelease?()
    }

    private func ratio(of node: LayoutNode) -> Double? {
        if case .split(_, _, let r, _, _) = node { return r }
        return nil
    }

    func testTurnedOnItShowsTheLinesOfTheScreenInViewAndTellsSo() {
        resizer.toggle()
        XCTAssertEqual(changes, [true])
        XCTAssertEqual(resizer.shownHandles.count, 1, "the one line of the screen's own layout")
        resizer.toggle()
        XCTAssertEqual(changes, [true, false])
        XCTAssertTrue(resizer.shownHandles.isEmpty)
    }

    func testItDoesNotTurnOnWhileBlocked() {
        blocked = true
        resizer.toggle()
        XCTAssertTrue(changes.isEmpty)
    }

    func testADragChangesTheShareOfTheScreensOwnLayoutAndTheWindowsGlideThere() {
        resizer.toggle()
        drag(to: 700)
        XCTAssertEqual(layouts.updates.count, 1)
        XCTAssertTrue(layouts.updates[0].animated)
        XCTAssertEqual(ratio(of: strip.root) ?? 0, 0.7, accuracy: 0.01)
        XCTAssertEqual(ratio(of: strip.trailing[0].root), 0.5, "the area beyond is left alone")
    }

    func testADragKeepsAZoneAtItsRatioAsTheLayoutEditorDoes() {
        let d = UUID()
        var layout = repository.layout(id: layoutID, key: key)!
        layout.strip.root = .split(id: UUID(), sideBySide: false, ratio: 0.5, first: .split(id: UUID(), sideBySide: true, ratio: 0.5, first: .leaf(a), second: .leaf(b)), second: .leaf(d))
        repository.setStrip(layout.strip, ofLayout: layoutID, key: key)
        repository.setZoneAspects([a: ZoneAspect(2, 1)], ofLayout: layoutID, key: key)   // 500 x 250 now
        resizer.toggle()
        let mouse = resizer.shownHandles[1].mouse   // the vertical line
        mouse.onPress?()
        screens.pointerAX = CGPoint(x: 600, y: 250)
        mouse.onDrag?()
        mouse.onRelease?()
        guard case .split(_, _, let rows, let first, _) = strip.root, case .split(_, _, let columns, _, _) = first else { return XCTFail("the shape changed") }
        XCTAssertGreaterThan(columns, 0.51, "the line moved (to where the least zone size lets it)")
        XCTAssertEqual(rows, columns, accuracy: 0.001, "the horizontal line went with it: the zone is still two to one")
    }

    func testAClickThatMovesNothingChangesNothing() {
        resizer.toggle()
        let before = resizer.shownHandles[0]
        before.mouse.onPress?()
        before.mouse.onRelease?()
        XCTAssertTrue(layouts.updates.isEmpty)
        XCTAssertTrue(resizer.shownHandles[0] === before, "and the handles stay as they are")
    }

    func testAtAnAreaBeyondTheEdgeTheLinesAreThoseOfThatAreaAndItsLayoutIsWhatChanges() {
        viewport.set(1000, for: key)   // the area is as wide as the screen and the gap is 0
        resizer.toggle()
        XCTAssertEqual(resizer.shownHandles.count, 1)
        drag(to: 300)
        XCTAssertEqual(ratio(of: strip.root), 0.5, "the screen's own layout is left alone")
        XCTAssertEqual(ratio(of: strip.trailing[0].root) ?? 0, 0.3, accuracy: 0.01)
    }

    func testBetweenTwoScreensThereAreNoLinesAndTheyComeBackAtTheRest() {
        viewport.set(400, for: key)
        resizer.toggle()
        XCTAssertTrue(resizer.shownHandles.isEmpty)
        viewport.set(1000, for: key)
        resizer.zonesDidChange()
        XCTAssertEqual(resizer.shownHandles.count, 1)
    }

    func testUndoTakesBackTheLastMoveAndTheMovesCanBeUndoneOneByOne() {
        resizer.toggle()
        drag(to: 700)
        drag(to: 400)
        XCTAssertEqual(undoStates, [true, true])
        resizer.undo()
        XCTAssertEqual(ratio(of: strip.root) ?? 0, 0.7, accuracy: 0.01)
        resizer.undo()
        XCTAssertEqual(ratio(of: strip.root) ?? 0, 0.5, accuracy: 0.0001, "back where it began")
        XCTAssertEqual(undoStates, [true, true, true, false])
        XCTAssertTrue(layouts.updates.suffix(2).allSatisfy(\.animated))
    }

    func testTheMovesAreForgottenWhenTheModeEnds() {
        resizer.toggle()
        drag(to: 700)
        resizer.toggle()
        XCTAssertEqual(undoStates, [true, false])
        resizer.toggle()
        resizer.undo()
        XCTAssertEqual(ratio(of: strip.root) ?? 0, 0.7, accuracy: 0.01, "nothing to undo in a new run of the mode")
    }

    func testTheModeEndsWhenTheDesktopItWasOnIsNotInView() {
        resizer.toggle()
        shownScreens = [screen("display|d2")]
        resizer.zonesDidChange()
        XCTAssertEqual(changes, [true, false])
        XCTAssertTrue(resizer.shownHandles.isEmpty)
    }

    func testItIsOnTheDisplayThePointerIsOn() {
        var other = screen("other|d1")
        other = ScreenInfo(key: other.key, name: "Other", size: other.size, cocoaFrame: CGRect(x: 1000, y: 0, width: 1000, height: 500),
                           cocoaVisibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 500), axVisible: CGRect(x: 1000, y: 0, width: 1000, height: 500))
        screens.infos = [screen(key), other]
        shownScreens = screens.infos
        screens.pointerAX = CGPoint(x: 1500, y: 250)
        resizer.toggle()
        XCTAssertTrue(resizer.shownHandles.isEmpty, "the display the pointer is on has no layout, and nothing is shown on the other")
    }
}
