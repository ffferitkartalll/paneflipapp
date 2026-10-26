import CoreGraphics
import Foundation

/// A screen's zones, those beyond its edges too, drawn small in a row: the little picture of the layout that the island shows in the menu bar.
public struct ZoneGlyph: Equatable {
    public struct Cell: Identifiable, Equatable {
        public let id: UUID
        /// In the picture, from its top left corner.
        public let rect: CGRect
        /// The zone lies on the screen; else it waits beyond an edge.
        public let isOnScreen: Bool
    }

    public let size: CGSize
    /// Where the screen itself lies in the picture.
    public let screen: CGRect
    /// Larger zones first, so that a zone floating over another is drawn after it.
    public let cells: [Cell]

    /// `zones` and `screen` are in the same coordinates; the screen is drawn `screenSize` big, the zones beyond its edges at the same scale. `screenShifts` are the farthest the screen can be scrolled either way from where it stands now: the picture is as wide as the whole strip can show, so that it does not change while the layout scrolls. Each zone grows by `grow` on every side: with half the gap between zones they meet.
    public init(zones: [(id: UUID, rect: CGRect)], screen: CGRect, screenSize: CGSize, grow: CGFloat = 0, screenShifts: ClosedRange<CGFloat> = 0...0) {
        let zones = zones.map { (id: $0.id, rect: $0.rect.insetBy(dx: -grow, dy: -grow)) }
        // Wider than the screen where zones wait beyond its edges, never taller.
        func joined(_ a: CGRect, _ b: CGRect) -> CGRect {
            CGRect(x: min(a.minX, b.minX), y: screen.minY, width: max(a.maxX, b.maxX) - min(a.minX, b.minX), height: screen.height)
        }
        let reach = joined(joined(screen, screen.offsetBy(dx: screenShifts.lowerBound, dy: 0)), screen.offsetBy(dx: screenShifts.upperBound, dy: 0))
        let all = zones.map(\.rect).reduce(reach, joined)
        let sx = screen.width > 0 ? screenSize.width / screen.width : 0
        let sy = screen.height > 0 ? screenSize.height / screen.height : 0
        func scaled(_ r: CGRect) -> CGRect {
            CGRect(x: (r.minX - all.minX) * sx, y: (r.minY - all.minY) * sy, width: r.width * sx, height: r.height * sy)
        }
        size = CGSize(width: all.width * sx, height: all.height * sy)
        self.screen = scaled(screen)
        cells = zones.sorted { $0.rect.width * $0.rect.height > $1.rect.width * $1.rect.height }.map {
            Cell(id: $0.id, rect: scaled($0.rect), isOnScreen: $0.rect.intersection(screen).width > 1)
        }
    }
}
