import AppKit
import XCTest
import CoreGraphics
import PaneFlipCore

extension LayoutAppsServiceTests {
    final class Refresher: ZoneRefreshing {
        var restores = 0
        var presenterRefreshes = 0
        func refreshZones() {}
        func refreshPresenters() { presenterRefreshes += 1 }
        func restoreWindows() { restores += 1 }
    }
}
