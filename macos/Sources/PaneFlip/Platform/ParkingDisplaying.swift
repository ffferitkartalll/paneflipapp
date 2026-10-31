import CoreGraphics

/// The hidden displays that windows out of sight wait on: one for each real display, made by the app, that no one can look at or reach with the pointer.
protocol ParkingDisplaying: AnyObject {
    /// Their numbers, so that they can be left out of the displays the app lays zones out on.
    var displayIDs: Set<CGDirectDisplayID> { get }
    /// The area the hidden display of a real display covers, in Accessibility coordinates; nil when it has none (that display then has no screens beyond its edges).
    func area(forDisplay id: CGDirectDisplayID) -> CGRect?
    /// Has a hidden display for each of the real displays `displays` (number and frame in Accessibility coordinates) when `enabled`, else none.
    func update(enabled: Bool, besides displays: [(id: CGDirectDisplayID, frame: CGRect)])
}
