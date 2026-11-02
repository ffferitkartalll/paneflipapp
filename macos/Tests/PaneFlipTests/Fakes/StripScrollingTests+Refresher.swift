import XCTest
import CoreGraphics
import PaneFlipCore

extension StripScrollingTests {
    final class Refresher: ZoneRefreshing {
        var onRefresh: () -> Void = {}
        func refreshZones() { onRefresh() }
        func restoreWindows() {}
    }
}
