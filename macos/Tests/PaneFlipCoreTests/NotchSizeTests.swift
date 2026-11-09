import CoreGraphics
import Testing
@testable import PaneFlipCore

struct NotchSizeTests {
    @Test func theNotchAtRestIsAsWideAsItsWindowsAsk() {
        #expect(NotchSize.size(forWindows: 1).width == 36)
        #expect(NotchSize.size(forWindows: 3).width == 60)
        #expect(NotchSize.size(forWindows: 6).width == 96)
        #expect(NotchSize.size(forWindows: 40).width == 120, "no wider than 120 pt")
        #expect(NotchSize.size(forWindows: 0).width == 36, "a zone without a window is drawn as one with one")
    }

    @Test func withThePointerOnItItIsTwiceAsTallAndNoWider() {
        #expect(NotchSize.hoverSize(forWindows: 3) == CGSize(width: 60, height: 12))
    }
}
