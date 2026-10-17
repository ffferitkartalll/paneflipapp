import CoreGraphics

/// A window as it looked when it was photographed.
struct WindowPicture {
    /// Without transparent corners: the picture is square, the zone's rounded edge is cut by the stage.
    let image: CGImage
    /// Where the window was, in top-left-origin (Accessibility) coordinates.
    let frame: CGRect
    /// The radius of the window's corners, in points.
    let cornerRadius: CGFloat
}
