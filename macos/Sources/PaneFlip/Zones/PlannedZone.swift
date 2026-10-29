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
    /// Its place in the order of all the zones of the strip, from the outermost on the left to the outermost on the right: the order the focus goes through the
    /// zones that lie side by side.
    let order: Int

    init(rect: CGRect, frame: CGRect? = nil, isParked: Bool = false, number: Int = 0, order: Int = 0) {
        self.number = number
        self.order = order
        self.rect = rect
        self.frame = frame ?? rect
        self.isParked = isParked
    }
}
