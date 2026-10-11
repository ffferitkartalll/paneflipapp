import ApplicationServices
import CoreGraphics

/// A handle to a window of another app: its system number, owner and accessibility element.
struct WindowRef {
    let id: CGWindowID
    let pid: pid_t
    let element: AXUIElement
}
