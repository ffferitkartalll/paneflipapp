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

    @Test func zonesGrownByHalfTheGapMeet() {
        let glyph = ZoneGlyph(zones: [(a, CGRect(x: 2, y: 2, width: 496, height: 496)), (b, CGRect(x: 502, y: 2, width: 496, height: 496))],
                              screen: screen, screenSize: CGSize(width: 100, height: 50), grow: 2)
        let rects = glyph.cells.map(\.rect).sorted { $0.minX < $1.minX }
        #expect(rects[0].maxX == rects[1].minX)
    }

    @Test func theRealGapIsTheGapOfTheLayoutInTheUnitsOfThePicture() {
        // The screen is drawn a tenth of its size: a gap of 20 is 2 in the picture; none is 0.
        let zones: [(id: UUID, rect: CGRect)] = [(a, CGRect(x: 0, y: 0, width: 500, height: 500))]
        let gapped = ZoneGlyph(zones: zones, screen: screen, screenSize: CGSize(width: 100, height: 50), grow: 10)
        let bare = ZoneGlyph(zones: zones, screen: screen, screenSize: CGSize(width: 100, height: 50))
        #expect(gapped.gap == 2)
        #expect(bare.gap == 0)
    }

    @Test func zonesAreOnePointApartAtRestAndTheRealGapShowsWhenOpenButNeverLess() {
        let zones: [(id: UUID, rect: CGRect)] = [(a, CGRect(x: 0, y: 0, width: 500, height: 500))]
        let size = CGSize(width: 100, height: 50)
        let wide = ZoneGlyph(zones: zones, screen: screen, screenSize: size, grow: 10)    // a gap of 2 in the picture
        let none = ZoneGlyph(zones: zones, screen: screen, screenSize: size)
        #expect(wide.inset(zoom: 1, openZoom: 5) == 0.5, "at rest: 1 pt apart whatever the gap")
        #expect(none.inset(zoom: 1, openZoom: 5) == 0.5)
        #expect(wide.inset(zoom: 5, openZoom: 5) == 5, "open: the real gap, 2 × 5 = 10 pt apart")
        #expect(none.inset(zoom: 5, openZoom: 5) == 0.5, "open, with no gap in the layout: still 1 pt")
        #expect(wide.inset(zoom: 3, openZoom: 5) == 1.75, "on the way it is between the two")
        #expect(wide.inset(zoom: 3, openZoom: 1) == 0.5, "an island that cannot grow stays at rest")
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
