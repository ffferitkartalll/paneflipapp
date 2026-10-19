import CoreGraphics

/// How far each screen's layout has been scrolled (see `StripGeometry`). Not kept between runs: every start shows the
/// screen's own layout.
final class StripViewport {
    private var offsets: [String: CGFloat] = [:]

    func offset(for key: String) -> CGFloat { offsets[key] ?? 0 }

    /// Every screen shows its own layout again.
    func reset() { offsets = [:] }

    func set(_ offset: CGFloat, for key: String) { offsets[key] = offset }
}
