/// Something that shows the zones' state (the pill) and wants to know when the set of zones changed.
protocol ZonePresenting: AnyObject {
    func zonesDidChange()
}
