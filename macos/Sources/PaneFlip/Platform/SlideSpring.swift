import QuartzCore

/// The spring of the slides inside a zone, which the windows of a floating zone follow too: critically damped, so it lands softly
/// without overshoot.
enum SlideSpring {
    static let stiffness: CGFloat = 320
    static let damping: CGFloat = 36

    /// How long the spring takes to settle.
    static let settling: CFTimeInterval = {
        let spring = CASpringAnimation(keyPath: "position.x")
        spring.mass = 1
        spring.stiffness = stiffness
        spring.damping = damping
        return spring.settlingDuration
    }()

    /// How far along the way (0 to 1) the spring is `time` seconds after it began.
    static func progress(at time: CFTimeInterval) -> Double {
        let omega = Double(stiffness).squareRoot()
        return 1 - (1 + omega * time) * exp(-omega * time)
    }
}
