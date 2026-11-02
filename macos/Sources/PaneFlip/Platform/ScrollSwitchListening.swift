import CoreGraphics
import Foundation

/// The scroll that moves through the windows of a zone, or on to the zones beyond the screen's edges, heard anywhere in the system:
/// three or four fingers on the trackpad lead the slide, and the mouse wheel with the chosen keys held steps (the wheel's scrolling is
/// not passed on to the app under the pointer).
protocol ScrollSwitchListening {
    /// Starts listening; `onEvent` runs on the main thread. Needs the Accessibility permission.
    func start(onEvent: @escaping (ScrollSwitchEvent) -> Void)
}
