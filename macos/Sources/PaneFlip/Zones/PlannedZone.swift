import CoreGraphics

/// A zone as laid out for the current scroll of its screen.
struct PlannedZone: Equatable {
    /// Where the zone stands, in top-left-origin (Accessibility) coordinates; outside the screen when it is scrolled away.
    let rect: CGRect
    /// Where its windows stand: the zone itself, or the place a window waits when the zone is out of sight.
    let frame: CGRect
    let isParked: Bool

    init(rect: CGRect, frame: CGRect? = nil, isParked: Bool = false) {
        self.rect = rect
        self.frame = frame ?? rect
        self.isParked = isParked
    }
}
