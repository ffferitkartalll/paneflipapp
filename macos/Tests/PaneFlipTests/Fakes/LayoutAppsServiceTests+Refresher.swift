import AppKit
import XCTest
import CoreGraphics
import PaneFlipCore

extension LayoutAppsServiceTests {
    final class Refresher: ZoneRefreshing {
        var restores = 0
        func refreshZones() {}
        func restoreWindows() { restores += 1 }
    }
}
