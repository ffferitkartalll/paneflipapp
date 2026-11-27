/// How the wheel of a mouse with a switchable wheel turns now: with a click at every step, or free (a flick goes on turning). Pure.
public enum WheelMode: Equatable {
    case freeSpin
    case ratchet
}
