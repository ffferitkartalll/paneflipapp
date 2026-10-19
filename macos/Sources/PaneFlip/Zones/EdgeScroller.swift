import CoreGraphics
import Foundation
import PaneFlipCore

/// Scrolls the layout when the pointer rests at the left or right edge of a screen for a moment: the zones beyond that edge come
/// into view. Going back, from zones that are in view, takes no wait. Once it has scrolled, the pointer must leave the edge and
/// come back to scroll again.
final class EdgeScroller {
    /// How close to the edge of the screen counts as at the edge, in points (the pointer stops at the edge itself).
    private static let reach: CGFloat = 2

    private let listener: PointerMoveListening
    private let screens: ScreenProviding
    private let settings: AppSettings
    private let scroller: StripScroller
    private let dwell: TimeInterval
    /// Calls `work` after `delay`; returns what cancels it.
    private let after: (_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void
    private var waiting: (edge: ScreenEdge, key: String, cancel: () -> Void)?
    /// False after a scroll, until the pointer has left the edge.
    private var armed = true
    private var isRunning = false

    init(listener: PointerMoveListening, screens: ScreenProviding, settings: AppSettings, scroller: StripScroller,
         dwell: TimeInterval = 1, after: @escaping (_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void) {
        self.listener = listener
        self.screens = screens
        self.settings = settings
        self.scroller = scroller
        self.dwell = dwell
        self.after = after
    }

    /// The app is up: watch the pointer if the setting is on.
    func start() {
        isRunning = true
        settingDidChange()
    }

    /// Watches the pointer only while the setting is on.
    func settingDidChange() {
        waiting?.cancel()
        waiting = nil
        armed = true
        if isRunning && settings.values.overflowZonesEnabled && settings.values.edgeScrollEnabled { listener.start { [weak self] in self?.moved(to: $0) } }
        else { listener.stop() }
    }

    private func moved(to point: CGPoint) {
        guard let (screen, edge) = edge(at: point) else {
            waiting?.cancel()
            waiting = nil
            armed = true
            return
        }
        if let waiting, waiting.edge == edge, waiting.key == screen.key { return }   // still resting there
        waiting?.cancel()
        waiting = nil
        guard armed else { return }
        // Going back to where the layout began needs no wait: only going further out does.
        if scroller.isReturning(toward: edge, on: screen) {
            if scroller.scroll(toward: edge, on: screen) { armed = false }
            return
        }
        let key = screen.key
        let cancel = after(dwell) { [weak self] in self?.rested(on: edge, of: key) }
        waiting = (edge, key, cancel)
    }

    /// The pointer has been at the edge for the time: scroll, if it still is.
    private func rested(on edge: ScreenEdge, of key: String) {
        waiting = nil
        guard settings.values.edgeScrollEnabled, let (screen, now) = self.edge(at: screens.pointerCocoa), now == edge, screen.key == key
        else { return }
        if scroller.scroll(toward: edge, on: screen) { armed = false }
    }

    private func edge(at point: CGPoint) -> (ScreenInfo, ScreenEdge)? {
        for screen in screens.screens() {
            let frame = screen.cocoaFrame
            guard point.y >= frame.minY, point.y <= frame.maxY else { continue }
            if point.x >= frame.minX - 1, point.x <= frame.minX + Self.reach { return (screen, .left) }
            if point.x <= frame.maxX + 1, point.x >= frame.maxX - Self.reach { return (screen, .right) }
        }
        return nil
    }
}
