import CoreGraphics

/// What made a scroll event: a wheel that clicks, a wheel a mouse driver smooths, a free-spinning wheel, or fingers on a trackpad. Pure.
public enum WheelKind: Equatable {
    /// How far a free-spinning wheel's points move the content, against fingers' (a driver sends far more points a second than fingers do).
    /// shortcut: tuned by eye, change it if a flick goes too far or not far enough.
    public static let freeSpinGain: CGFloat = 0.3

    /// A wheel whose every event is a click.
    case notch
    /// A wheel whose driver smooths it into many small events of a click (continuous events with no touch phase at all, which fingers never send), in ratchet or when the mouse cannot say.
    case smooth
    /// Such a wheel in free spin: a swipe, as of fingers.
    case freeSpin
    case fingers

    /// `mode` is asked only for a smooth stream, so a mouse is read only when a driver makes one.
    public init(continuous: Bool, phase: Int, momentum: Int, mode: () -> WheelMode?) {
        guard continuous else { self = .notch; return }
        guard phase == 0, momentum == 0 else { self = .fingers; return }
        self = mode() == .freeSpin ? .freeSpin : .smooth
    }
}
