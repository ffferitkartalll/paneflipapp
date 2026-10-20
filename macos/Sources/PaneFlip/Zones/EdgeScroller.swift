import CoreGraphics
import Foundation
import PaneFlipCore

/// Scrolls the layout at once when the pointer reaches the left or right edge of a screen: the zones beyond that edge come into
/// view. While the pointer stays there it goes on, a rest position at a time, until there is nothing more that way; after that
/// the pointer must leave the edge and come back to scroll again.
final class EdgeScroller {
    /// How close to the edge of the screen counts as at the edge, in points (the pointer stops at the edge itself).
    private static let reach: CGFloat = 2

    private let listener: PointerMoveListening
    private let screens: ScreenProviding
    private let settings: AppSettings
    private let scroller: StripScroller
    /// False once the pointer has been dealt with at an edge, until it has left the edge.
    private var armed = true
    /// A scroll this pointer started has run and the next one is due when it comes to rest, if the pointer is still there.
    private var continuing = false
    private var isRunning = false

    init(listener: PointerMoveListening, screens: ScreenProviding, settings: AppSettings, scroller: StripScroller) {
        self.listener = listener
        self.screens = screens
        self.settings = settings
        self.scroller = scroller
        scroller.onRest = { [weak self] in self?.continueAtTheEdge() }
    }

    /// The app is up: watch the pointer if the setting is on.
    func start() {
        isRunning = true
        settingDidChange()
    }

    /// Watches the pointer only while the setting is on.
    func settingDidChange() {
        armed = true
        continuing = false
        if isRunning && settings.values.overflowZonesEnabled { listener.start { [weak self] in self?.moved(to: $0) } }
        else { listener.stop() }
    }

    private func moved(to point: CGPoint) {
        guard let (frame, edge) = edge(at: point) else {
            armed = true
            continuing = false
            return
        }
        guard armed else { return }
        // One look per visit to the edge, whatever comes of it: it costs the screens' list, and this runs on every mouse move.
        armed = false
        guard let screen = screen(with: frame) else { return }
        continuing = scroller.scroll(toward: edge, on: screen)
    }

    /// A scroll has come to rest: if the pointer still is at the edge it scrolled toward, the next rest position is brought in.
    private func continueAtTheEdge() {
        guard continuing, settings.values.overflowZonesEnabled, let (frame, edge) = edge(at: screens.pointerCocoa),
              let screen = screen(with: frame) else { continuing = false; return }
        continuing = scroller.scroll(toward: edge, on: screen)
    }

    /// The edge of a display the point lies at, with that display's frame. This runs on every mouse move of the system, so it
    /// asks for plain frames only.
    private func edge(at point: CGPoint) -> (frame: CGRect, edge: ScreenEdge)? {
        for frame in screens.frames {
            guard point.y >= frame.minY, point.y <= frame.maxY else { continue }
            if point.x >= frame.minX - 1, point.x <= frame.minX + Self.reach { return (frame, .left) }
            if point.x <= frame.maxX + 1, point.x >= frame.maxX - Self.reach { return (frame, .right) }
        }
        return nil
    }

    private func screen(with frame: CGRect) -> ScreenInfo? { screens.screens().first { $0.cocoaFrame == frame } }
}
