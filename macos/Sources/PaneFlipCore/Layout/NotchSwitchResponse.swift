import Foundation

/// What the notch of a zone does while the zone's windows are switched (a shortcut, the wheel, the fingers).
public enum NotchSwitchResponse: Equatable {
    /// It grows into the row of the zone's windows.
    case grow
    /// It stays closed but shows as it does with the pointer on it, for the moment of the switch.
    case lift
    /// It stays as it is.
    case stay

    /// `opensOnClickOnly`: the notch grows only when it is clicked, never for a switch; `liftsOnSwitch`: then it shows as with the pointer on it meanwhile. A notch that is
    /// grown already (it was clicked) goes on following the switches.
    public static func of(opensOnClickOnly: Bool, liftsOnSwitch: Bool, grown: Bool) -> NotchSwitchResponse {
        guard opensOnClickOnly, !grown else { return .grow }
        return liftsOnSwitch ? .lift : .stay
    }
}
