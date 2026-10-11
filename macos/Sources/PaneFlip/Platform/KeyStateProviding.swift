/// Real-time keyboard state.
protocol KeyStateProviding {
    func isDown(keyCode: Int) -> Bool
}
