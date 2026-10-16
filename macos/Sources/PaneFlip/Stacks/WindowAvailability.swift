import CoreGraphics

/// Decides whether a window that PaneFlip stacked has effectively gone away.
final class WindowAvailability {
    private let windows: WindowSystem
    private let screens: ScreenProviding

    init(windows: WindowSystem, screens: ScreenProviding) {
        self.windows = windows
        self.screens = screens
    }

    func snapshot() -> WindowSnapshot {
        let sets = windows.windowSets()
        return WindowSnapshot(all: sets.all, onScreen: sets.onScreen, currentSpaces: screens.currentSpaceIDs())
    }

    /// Closed windows either vanish from the system list or, for apps that merely hide a window on close
    /// (some even hide the whole app), stay listed but belong to the current desktop
    /// without being on screen. Minimized windows count as gone too; windows on another desktop do not.
    func isGone(_ ref: WindowRef, in snapshot: WindowSnapshot) -> Bool {
        guard snapshot.all.contains(ref.id) else { return true }
        if snapshot.onScreen.contains(ref.id) { return false }
        let spaces = screens.spaces(ofWindow: ref.id)
        if spaces.isEmpty { return true }
        if !spaces.isSubset(of: snapshot.currentSpaces) { return false }
        return true
    }
}
