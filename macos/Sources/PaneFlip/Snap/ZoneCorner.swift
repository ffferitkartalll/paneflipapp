import CoreGraphics

/// The corners of a lit zone: those of a window of macOS (measured on the system's windows: continuous corners with this radius), so that a zone lights up in the shape of the window that goes into it.
enum ZoneCorner {
    static let radius: CGFloat = 17.3
}
