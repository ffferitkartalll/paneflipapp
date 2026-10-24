import CoreGraphics

/// A zone as laid out for the current scroll of its screen.
struct PlannedZone: Equatable {
    /// Where the zone stands, in top-left-origin (Accessibility) coordinates; outside the screen when it is scrolled away.
    let rect: CGRect
    /// Where its windows stand: the zone itself, or the place a window waits when the zone is out of sight.
    let frame: CGRect
    let isParked: Bool
    /// The number the zone shows (its place in its layout); decides between zones that are equally near.
    let number: Int
    /// The zone floats over another one. While the focus is elsewhere its windows wait at `awayFrame` (the screen's right edge);
    /// nil: there is no such place (a display lies there), and they stay.
    let isFloating: Bool
    let awayFrame: CGRect?

    init(rect: CGRect, frame: CGRect? = nil, isParked: Bool = false, number: Int = 0, isFloating: Bool = false, awayFrame: CGRect? = nil) {
        self.isFloating = isFloating
        self.awayFrame = awayFrame
        self.number = number
        self.rect = rect
        self.frame = frame ?? rect
        self.isParked = isParked
    }
}
