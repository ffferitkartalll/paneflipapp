import CoreGraphics

/// Everything the app needs to know about displays, desktops and the pointer.
protocol ScreenProviding {
    func screens() -> [ScreenInfo]
    /// The Dock stands on a connected display (or is hidden): after a display was unplugged it lands on a remaining one a moment later, and until
    /// then the usable area of the displays does not yet make room for it.
    var isDockSettled: Bool { get }
    /// The desktop currently shown on each display.
    func currentSpaceIDs() -> Set<UInt64>
    /// The desktops a window belongs to; empty once it has been closed.
    func spaces(ofWindow id: CGWindowID) -> Set<UInt64>
    /// Pointer in top-left-origin (Accessibility) coordinates.
    var pointerAX: CGPoint { get }
    /// Pointer in bottom-left-origin (Cocoa) coordinates.
    var pointerCocoa: CGPoint { get }
    var menuBarThickness: CGFloat { get }
    /// Mission Control or App Exposé is showing: windows are rearranged or hidden and should be left alone.
    var isMissionControlActive: Bool { get }
    /// Cocoa ↔ Accessibility rectangle conversion (the transform is its own inverse).
    func flip(_ rect: CGRect) -> CGRect
}
