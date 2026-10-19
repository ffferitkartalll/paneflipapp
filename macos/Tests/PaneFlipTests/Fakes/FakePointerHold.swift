final class FakePointerHold: PointerHolding {
    private(set) var isHeld = false
    private(set) var holds = 0

    func hold(_ on: Bool) {
        isHeld = on
        if on { holds += 1 }
    }
}
