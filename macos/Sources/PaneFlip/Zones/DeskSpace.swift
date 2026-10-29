import CoreGraphics
import PaneFlipCore

/// Brings rectangles from where the system arranges the displays to where the user says they stand on the desk, for the moves from one display to
/// the one beside it. Without a desk arrangement set for every display the rectangles stay as they are.
struct DeskSpace {
    let screens: ScreenProviding
    let arrangement: () -> DeskArrangement

    /// `rect` in top-left-origin (Accessibility) coordinates, moved with the display it belongs to. Unchanged without a desk arrangement.
    func rect(_ rect: CGRect) -> CGRect {
        let displays = Self.distinct(screens.screens())
        let desk = arrangement()
        let sizes = displays.map { (id: $0.displayID, size: $0.size) }
        guard desk.isSet(for: sizes), let owner = display(of: rect, among: displays), let deskFrame = desk.frames(of: sizes)[owner.screen.displayID] else { return rect }
        return DeskArrangement.map(rect, from: owner.frame, to: deskFrame)
    }

    /// The display a rectangle belongs to: the one it lies in, else the one whose height it shares (a zone kept beyond a display's edge keeps the height of
    /// its zones), else the nearest. Nil without displays.
    func display(of rect: CGRect) -> String? { display(of: rect, among: Self.distinct(screens.screens()))?.screen.displayID }

    private func display(of rect: CGRect, among displays: [ScreenInfo]) -> (screen: ScreenInfo, frame: CGRect)? {
        let middle = CGPoint(x: rect.midX, y: rect.midY)
        return displays.map { (screen: $0, frame: screens.flip($0.cocoaFrame)) }.min {
            let (inA, inB) = ($0.frame.contains(middle), $1.frame.contains(middle))
            if inA != inB { return inA }
            let (a, b) = (overlap(rect, $0.frame), overlap(rect, $1.frame))
            return a != b ? a > b : distance(from: middle, to: $0.frame) < distance(from: middle, to: $1.frame)
        }
    }

    /// One entry per display, whatever its desktop, from left to right in the system's arrangement.
    static func distinct(_ screens: [ScreenInfo]) -> [ScreenInfo] {
        var seen = Set<String>()
        return screens.filter { seen.insert($0.displayID).inserted }.sorted { $0.cocoaFrame.minX < $1.cocoaFrame.minX }
    }

    private func overlap(_ rect: CGRect, _ frame: CGRect) -> CGFloat { max(min(rect.maxY, frame.maxY) - max(rect.minY, frame.minY), 0) }

    private func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let dx = max(frame.minX - point.x, 0, point.x - frame.maxX), dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
