import CoreGraphics
import Foundation
import Testing
@testable import PaneFlipCore

struct ZoneGlyphTests {
    private let a = UUID(), b = UUID(), beyond = UUID()
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 500)

    @Test func drawsTheScreenAtTheGivenSize() {
        let glyph = ZoneGlyph(zones: [(a, CGRect(x: 0, y: 0, width: 500, height: 500)), (b, CGRect(x: 500, y: 0, width: 500, height: 500))],
                              screen: screen, screenSize: CGSize(width: 100, height: 50))
        #expect(glyph.size == CGSize(width: 100, height: 50))
        #expect(glyph.cells.map(\.rect).contains(CGRect(x: 50, y: 0, width: 50, height: 50)))
        #expect(glyph.cells.allSatisfy { $0.isOnScreen })
    }

    @Test func zonesBeyondTheEdgeWidenThePictureAndShiftTheScreen() {
        let glyph = ZoneGlyph(zones: [(a, screen), (beyond, CGRect(x: -500, y: 0, width: 500, height: 500))],
                              screen: screen, screenSize: CGSize(width: 100, height: 50))
        #expect(glyph.size.width == 150)
        #expect(glyph.screen == CGRect(x: 50, y: 0, width: 100, height: 50))
        #expect(glyph.cells.first(where: { $0.id == beyond })?.isOnScreen == false)
    }

    @Test func aZoneFloatingOverAnotherIsDrawnAfterIt() {
        let glyph = ZoneGlyph(zones: [(b, CGRect(x: 250, y: 100, width: 500, height: 300)), (a, screen)],
                              screen: screen, screenSize: CGSize(width: 100, height: 50))
        #expect(glyph.cells.map(\.id) == [a, b])
    }

    @Test func zonesGrownByHalfTheGapMeet() {
        let glyph = ZoneGlyph(zones: [(a, CGRect(x: 2, y: 2, width: 496, height: 496)), (b, CGRect(x: 502, y: 2, width: 496, height: 496))],
                              screen: screen, screenSize: CGSize(width: 100, height: 50), grow: 2)
        let rects = glyph.cells.map(\.rect).sorted { $0.minX < $1.minX }
        #expect(rects[0].maxX == rects[1].minX)
    }

    @Test func theWholeReachOfTheScrollIsInThePicture() {
        // A strip of 1600 on a screen of 1000, scrolled 0 or 600: the picture is the same size at both.
        let size = CGSize(width: 100, height: 50)
        let atStart = ZoneGlyph(zones: [(a, CGRect(x: 0, y: 0, width: 1600, height: 500))], screen: screen, screenSize: size, screenShifts: 0 ... 600)
        let atEnd = ZoneGlyph(zones: [(a, CGRect(x: -600, y: 0, width: 1600, height: 500))], screen: screen, screenSize: size, screenShifts: -600 ... 0)
        #expect(atStart.size == atEnd.size)
        #expect(atStart.cells == atEnd.cells)
        #expect(atStart.screen.minX == 0 && atEnd.screen.minX == 60)
    }
}
