import Foundation

/// Which zones show a notch: the zone with the focus (on whichever display), and the one whose notch is grown until it is back; no other, and none for the zone
/// a window of which is being dragged.
public enum NotchVisibility {
    public static func zones(among visible: [UUID], focused: UUID?, grown: UUID?, dragged: UUID? = nil) -> Set<UUID> {
        Set(visible.filter { ($0 == focused || $0 == grown) && $0 != dragged })
    }
}
