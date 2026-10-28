import Foundation

/// Remembers the display that was unplugged with the Dock on it. The Dock stays on the display it moved to until the person moves it back, so
/// until then that display, once it is plugged in again, is laid out as if the Dock had never left it.
public struct DockHome {
    private var displays: Set<String> = []
    private var dockDisplay: String?
    private var missed: String?

    public init() {}

    /// Told at every look at the displays and at where the Dock stands. While the displays change, the answer about the Dock is not trusted (it
    /// still points at the place the Dock left).
    public mutating func update(displays now: Set<String>, dockDisplay dock: String?) {
        if now != displays {
            if let was = dockDisplay, !displays.isEmpty, !now.contains(was) { missed = was }
            displays = now
        } else if let dock {
            dockDisplay = dock
        }
        if let dock, dock == missed { missed = nil }
    }

    /// The connected display that is laid out as if the Dock stood on it, if any.
    public var phantom: String? { missed.flatMap { displays.contains($0) ? $0 : nil } }
}
