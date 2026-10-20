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
}
