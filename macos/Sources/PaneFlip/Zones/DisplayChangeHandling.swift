/// Told when displays were plugged in or out, before the zones are laid out again.
protocol DisplayChangeHandling: AnyObject {
    func displaysDidChange()
}
