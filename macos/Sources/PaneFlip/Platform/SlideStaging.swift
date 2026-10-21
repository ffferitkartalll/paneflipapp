import CoreGraphics

/// Shows one picture sliding out of a zone while another slides in, inside the zone and nowhere else.
protocol SlideStaging {
    /// Slides `entering` in beside `leaving` (the size of the zone, side by side) and calls `completion` when done.
    /// `zone` is in top-left-origin (Accessibility) coordinates. `forward`: the new picture comes in from the right.
    /// `covered` runs once `leaving` is really on screen over the zone: only then may the real windows change, or
    /// the new one would show for a moment before the pictures are there. It is given a `done` to call when the real
    /// window is in place; the pictures give way to the real windows only after that. The slide starts right after
    /// `covered` runs.
    func slide(leaving: WindowPicture, entering: WindowPicture, in zone: CGRect, forward: Bool,
               covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void)

    /// Carries the slide that is running on to one more picture in the same direction: everything moves one more zone along
    /// and `entering` comes in. `covered` is as in `slide`. False when no such slide is running, or it is already giving way
    /// to the real windows; nothing has happened then.
    func extend(entering: WindowPicture, forward: Bool, covered: @escaping (_ done: @escaping () -> Void) -> Void) -> Bool

    /// A slide the fingers lead. The pictures of the zone's windows, `pictures[current]` the one in front, stand side by side in the
    /// zone and follow `scrub`; `endScrub` lets go. False when there is nothing to show (no screen shows the zone).
    func beginScrub(pictures: [WindowPicture], current: Int, in zone: CGRect) -> Bool

    /// The fingers came down again while the pictures of a swipe still glide to their windows: the pictures stop where they are and
    /// follow the fingers again (`scrub`, `endScrub`). Returns how far they are from the window in front, which is where the new
    /// swipe goes on from; nil when no such glide runs.
    func catchScrub() -> CGFloat?

    /// Takes the pictures `offset` points from where they began (to the right is positive: the windows before come in). Past the
    /// first or the last the pictures give way a little and pull back.
    func scrub(to offset: CGFloat)

    /// The fingers lifted: the pictures glide on, `shift` windows from the one in front (0: back to it). `covered` and `completion`
    /// are as in `slide`; `covered` runs for a shift of 0 too, and then changes nothing.
    func endScrub(shift: Int, covered: @escaping (_ done: @escaping () -> Void) -> Void, completion: @escaping () -> Void)
}
