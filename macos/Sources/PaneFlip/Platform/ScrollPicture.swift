import CoreGraphics

/// A window's picture on the scroll stage.
struct ScrollPicture {
    let id: CGWindowID
    /// `frame` is where the picture stands before the scroll moves it.
    let picture: WindowPicture
}
