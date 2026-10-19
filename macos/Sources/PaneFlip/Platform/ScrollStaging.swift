import CoreGraphics

/// Shows the windows of a screen's zones as pictures that follow the fingers while the layout is scrolled, cut off at the
/// edge of the screen's usable area. The render server moves them: they glide whatever the windows or the machine are doing.
protocol ScrollStaging {
    /// Puts the pictures on screen over `visible` (top-left-origin coordinates), each where its frame says, exactly over the
    /// real window. `covered` runs once they are on screen: only then may the real windows change.
    func begin(pictures: [ScrollPicture], over visible: CGRect, covered: @escaping () -> Void)
    /// Newer pictures of windows already shown (a photograph that came after the pictures first shown).
    func update(pictures: [ScrollPicture])
    /// Moves all pictures to `shift` points right of where they began (negative: left), at once.
    func follow(shift: CGFloat)
    /// Takes the pictures away, softly, once the real windows stand where they are; `completion` runs when they are gone.
    func finish(completion: @escaping () -> Void)
}
