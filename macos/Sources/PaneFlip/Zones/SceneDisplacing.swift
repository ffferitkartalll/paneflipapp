/// Told whenever the zones are laid out: if displays were unplugged or plugged in since the last look, the windows of the unplugged ones are moved and those of the plugged-in ones come back.
protocol SceneDisplacing: AnyObject {
    func displaysDidChange(on screens: [ScreenInfo])
}
