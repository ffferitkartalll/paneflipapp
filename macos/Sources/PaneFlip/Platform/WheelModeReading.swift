import PaneFlipCore

/// How the wheel of the user's mouse turns now, when the mouse can say it (SmartShift).
protocol WheelModeReading: AnyObject {
    /// The mode last heard from the mouse, or nil when the mouse cannot say it (or has not answered yet). Cheap: the mouse is asked in the background.
    func mode() -> WheelMode?
}
