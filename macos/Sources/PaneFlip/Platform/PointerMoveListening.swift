import CoreGraphics

/// Where the pointer goes, heard anywhere in the system.
protocol PointerMoveListening: AnyObject {
    /// Starts listening; `onMove` gets the pointer's place (bottom-left-origin, Cocoa coordinates) on the main thread, for
    /// moves made without a button held.
    func start(onMove: @escaping (CGPoint) -> Void)
    func stop()
}
