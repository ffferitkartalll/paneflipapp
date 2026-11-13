/// Keeps the scrolling of a swipe with three or four fingers from the app under the pointer. Fingers land one after another, so the system takes the first two for a
/// scroll and goes on with it under the swipe; from the moment more fingers are down, that scroll (and the glide after it) is not the app's any more.
/// Value type; pure.
public struct CrowdedScroll {
    /// The beginning of a scroll went to the app, and its end has not.
    private var open = false
    /// More than two fingers came down in this touch: nothing goes through until another scroll begins without them.
    private var swallowing = false

    public init() {}

    /// A scroll event of the trackpad that would go to the app: `crowded` says three or more fingers have been down in the touch in progress, `phase` is the
    /// event's scroll phase (1 began, 2 changed, 4 ended, 8 cancelled, 128 may begin, 0 for the glide).
    public mutating func take(crowded: Bool, phase: Int) -> Verdict {
        if crowded { swallowing = true } else if phase == 1 || phase == 128 { swallowing = false }
        guard swallowing else {
            if phase == 1 { open = true } else if phase == 4 || phase == 8 { open = false }
            return .pass
        }
        guard open else { return .swallow }
        open = false
        return .end
    }
}
