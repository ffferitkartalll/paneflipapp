import CoreGraphics

/// Shows the window of a floating zone that goes as a picture, with the spring of the slides inside a zone (the window that comes is the real
/// one, which glides in with the same spring). The render server moves the picture: it glides whatever the apps or the machine are doing.
protocol FloatStaging {
    /// Puts the picture on screen exactly over the window and glides it out. `started` runs once the picture is on screen: only then may the
    /// real window go.
    func slide(_ slide: FloatSlide, started: @escaping () -> Void)
}
