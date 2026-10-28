import XCTest
import PaneFlipCore

final class DockHomeTests: XCTestCase {
    func testADisplayUnpluggedWithTheDockIsMissedWhenItComesBack() {
        var home = DockHome()
        home.update(displays: ["a", "b"], dockDisplay: "b")
        home.update(displays: ["a", "b"], dockDisplay: "b")
        home.update(displays: ["a"], dockDisplay: nil)          // b is unplugged with the Dock on it
        XCTAssertNil(home.phantom, "b is not there")
        home.update(displays: ["a"], dockDisplay: "a")          // the Dock lands on a
        home.update(displays: ["a", "b"], dockDisplay: "a")     // b comes back, the Dock stays on a
        XCTAssertEqual(home.phantom, "b")
    }

    func testTheDockComingBackEndsIt() {
        var home = DockHome()
        home.update(displays: ["a", "b"], dockDisplay: "b")
        home.update(displays: ["a", "b"], dockDisplay: "b")
        home.update(displays: ["a"], dockDisplay: "a")
        home.update(displays: ["a", "b"], dockDisplay: "a")
        home.update(displays: ["a", "b"], dockDisplay: "b")     // the person moved the Dock back
        XCTAssertNil(home.phantom)
    }

    func testADisplayWithoutTheDockIsNotMissed() {
        var home = DockHome()
        home.update(displays: ["a", "b"], dockDisplay: "a")
        home.update(displays: ["a", "b"], dockDisplay: "a")
        home.update(displays: ["a"], dockDisplay: "a")
        home.update(displays: ["a", "b"], dockDisplay: "a")
        XCTAssertNil(home.phantom)
    }
}
