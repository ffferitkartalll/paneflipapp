import CoreGraphics

/// Everything the app needs to know about displays, desktops and the pointer.
protocol ScreenProviding {
    func screens() -> [ScreenInfo]
    /// Only the frames of the displays (Cocoa coordinates): cheap, for code that runs on every mouse move. `screens()` asks the
    /// Dock for its size and reads the desktops.
    var frames: [CGRect] { get }
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
