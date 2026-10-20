import CoreGraphics

/// Reading and moving other apps' windows. The app's only door to the Accessibility API.
protocol WindowSystem {
    /// Whether the accessibility permission is granted. Asking for it is `PermissionChecking`'s job.
    var isTrusted: Bool { get }

    func focusedWindow() -> WindowRef?
    func windowUnderPointer() -> (ref: WindowRef, frame: CGRect)?
    /// Standard, non-minimized windows of an app on the current desktop.
    func windows(ofApp pid: pid_t) -> [WindowRef]

    /// Whether the app has a window on a screen right now (not minimized, not on another desktop): the one thing an app
    /// that was closed with Cmd+W lacks while it is still running.
    func isShowingWindow(ofApp pid: pid_t) -> Bool

    func frame(of ref: WindowRef) -> CGRect?
    func setFrame(_ rect: CGRect, of ref: WindowRef)
    /// Moves the window without touching its size: one write, for movement that follows the fingers.
    func setPosition(_ point: CGPoint, of ref: WindowRef)
    func title(of ref: WindowRef) -> String?
    func isMinimized(_ ref: WindowRef) -> Bool
    func raise(_ ref: WindowRef)

    /// Numbers of every window on the system (closed-but-hidden ones included) and of those on screen, from one system call.
    func windowSets() -> (all: Set<CGWindowID>, onScreen: Set<CGWindowID>)
    /// On-screen windows, frontmost first.
    func windowIDsFrontToBack() -> [CGWindowID]
}
