import CoreGraphics

/// A window of a floating zone going out beyond the screen's edge. All frames in top-left-origin (Accessibility) coordinates.
struct FloatSlide {
    let picture: WindowPicture
    /// Where the window stands, and where it goes (beyond the edge).
    let from: CGRect
    let to: CGRect
    /// Brings the window that has the focus in front again, once the picture is on screen: the picture lies over every window, and a window
    /// that is raised goes over it. So the picture goes out from behind that window, never in front of it, and in front of every other. Nil
    /// when no window has the focus: the picture is in front of every window then.
    var raiseFocused: (() -> Void)?
}
