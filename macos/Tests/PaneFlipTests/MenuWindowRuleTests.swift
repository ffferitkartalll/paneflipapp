import CoreGraphics
import Testing

/// Which windows say that a menu or the Dock is in use (and so keep the launchers away), and which do not.
struct MenuWindowRuleTests {
    private let hung = CGRect(x: 4000, y: 40, width: 300, height: 400)

    @Test func menusOfTheMenuBarAndTheDockAndPopoversCount() {
        #expect(MenuWindowRule.isMenu(layer: 101, owner: "Anything", rect: CGRect(x: 3000, y: 600, width: 200, height: 300)))
        #expect(MenuWindowRule.isMenu(layer: 20, owner: "Dock", rect: CGRect(x: 3000, y: 1200, width: 120, height: 40)))
        #expect(MenuWindowRule.isMenu(layer: 25, owner: "Anything", rect: hung))
    }

    @Test func aMenuTallerThanAThousandPointsCounts() {
        #expect(MenuWindowRule.isMenu(layer: 101, owner: "Anything", rect: CGRect(x: 3000, y: 40, width: 260, height: 1380)))
    }

    @Test func aSmallFloatingWindowDoesNotCount() {
        #expect(!MenuWindowRule.isMenu(layer: 3, owner: "Player", rect: CGRect(x: 4800, y: 1000, width: 400, height: 225)))
        #expect(!MenuWindowRule.isMenu(layer: 25, owner: "Recorder", rect: CGRect(x: 4800, y: 1300, width: 200, height: 60)))
    }

    @Test func theMenuBarIconsAndWholeDisplayWindowsDoNotCount() {
        #expect(!MenuWindowRule.isMenu(layer: 25, owner: "Icon", rect: CGRect(x: 4000, y: 0, width: 30, height: 30)))
        #expect(!MenuWindowRule.isMenu(layer: 20, owner: "Dock", rect: CGRect(x: 0, y: 0, width: 5120, height: 1440)))
        #expect(!MenuWindowRule.isMenu(layer: 24, owner: "Window Server", rect: hung))
    }
}
