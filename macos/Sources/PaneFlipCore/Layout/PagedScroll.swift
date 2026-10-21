import CoreGraphics

/// Turns scrolling into steps from one screen of a strip to the next: a swipe with two fingers moves one screen, once it has gone far
/// enough and however much further it goes on, and each notch of a mouse wheel moves one. Value type; pure.
public struct PagedScroll: Equatable {
    /// How far the fingers must go sideways, in points, for the swipe to move a screen.
    public static let distance: CGFloat = 60

    private var gone: CGFloat = 0
    private var stepped = false

    public init() {}

    /// The fingers moved by `horizontal` points (to the right is positive), or let go (`finished`). Returns the step to take:
    /// +1 to the screen on the right (the content went to the left), -1 to the one on the left, 0 for none yet. A swipe moves one
    /// screen at most; the next needs fingers that lifted and came down again.
    public mutating func add(horizontal: CGFloat, finished: Bool) -> Int {
        defer { if finished { gone = 0; stepped = false } }
        guard !finished, !stepped else { return 0 }
        gone += horizontal
        guard abs(gone) >= Self.distance else { return 0 }
        stepped = true
        return gone < 0 ? 1 : -1
    }

    /// One notch of a mouse wheel: turned toward you (negative) moves to the screen on the right, away from you to the left.
    public static func notch(_ delta: CGFloat) -> Int { delta == 0 ? 0 : (delta < 0 ? 1 : -1) }
}
