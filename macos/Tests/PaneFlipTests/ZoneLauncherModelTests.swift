import CoreGraphics
import Testing
import SwiftUI
import Foundation

@MainActor
struct ZoneLauncherModelTests {
    private func model() -> ZoneLauncherModel {
        let m = ZoneLauncherModel()
        m.placed = ["a", "b", "c"].map { LauncherApp(bundleID: $0, name: $0) }
        for (i, id) in ["a", "b", "c"].enumerated() { m.frames[id] = CGRect(x: CGFloat(i) * 100, y: 0, width: 90, height: 90) }
        return m
    }

    @Test func carriedAppFollowsThePointerAndTheOrderIsKept() {
        let m = model()
        var moved: (String, Int)?
        m.onMove = { moved = ($0, $1) }
        m.carry("a", at: CGPoint(x: 10, y: 10))
        #expect(m.carried == "a")
        m.drag(to: CGPoint(x: 150, y: 20))
        #expect(m.placed.map(\.bundleID) == ["b", "a", "c"])
        #expect(m.carriedOffset == CGSize(width: 150 - 10 - 100, height: 0))
        m.drop()
        #expect(m.carried == nil && moved?.0 == "a" && moved?.1 == 1)
    }

    @Test func carriedAppStaysInsideTheContent() {
        let m = model()
        m.carry("a", at: CGPoint(x: 10, y: 10))
        m.drag(to: CGPoint(x: -500, y: 900))
        #expect(m.carriedOffset.width >= 0 && m.carriedOffset.height == 0)
    }
}
