final class FakeKeys: KeyStateProviding {
    var down: Set<Int> = []
    func isDown(keyCode: Int) -> Bool { down.contains(keyCode) }
}
