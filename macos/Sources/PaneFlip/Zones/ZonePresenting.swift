/// Something that shows the zones' state (the island) and wants to know when the set of zones changed.
protocol ZonePresenting: AnyObject {
    func zonesDidChange()
}
