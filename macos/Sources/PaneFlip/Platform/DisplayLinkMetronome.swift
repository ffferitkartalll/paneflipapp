import AppKit

/// Calls a function once for every refresh of a screen, in step with it: a window written at a random moment between two
/// refreshes is shown no sooner than one written just before, and two writes within one refresh become one position.
final class DisplayLinkMetronome: NSObject {
    private var link: CADisplayLink?
    private var tick: (() -> Bool)?

    /// Runs `tick` on the main thread for each refresh of the screen under the pointer, until it returns false.
    static func start(_ tick: @escaping () -> Bool) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let metronome = DisplayLinkMetronome()
        metronome.tick = tick
        metronome.link = screen.displayLink(target: metronome, selector: #selector(fire(_:)))
        metronome.link?.add(to: .main, forMode: .common)
    }

    @objc private func fire(_ link: CADisplayLink) {
        guard tick?() == true else {
            link.invalidate()   // the link keeps this object alive until here
            tick = nil
            self.link = nil
            return
        }
    }
}
