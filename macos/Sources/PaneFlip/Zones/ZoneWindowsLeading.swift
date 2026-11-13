import CoreGraphics

/// What the fingers lead: the grid of the windows of the zone under the pointer, which opens with a swipe up and closes with one down, following the fingers.
protocol ZoneWindowsLeading: AnyObject {
    /// The fingers went `up` points (negative: down). The first move that points the way a swipe can go (up with the grid shut, down with it open) takes hold.
    func moveLead(by up: CGFloat)
    /// The fingers lifted: the grid goes on to where it was heading if the fingers took it far enough, or back.
    func endLead()
}
