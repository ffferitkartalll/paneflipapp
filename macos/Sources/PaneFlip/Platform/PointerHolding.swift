/// Keeps the pointer where it is: three fingers on the trackpad would otherwise move it while the layout scrolls.
protocol PointerHolding: AnyObject {
    /// While held, the pointer ignores the trackpad. Needs the Accessibility permission the app already has.
    func hold(_ on: Bool)
}
