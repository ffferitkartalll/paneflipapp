/// How the app got onto this Mac.
protocol InstallSourceDetecting {
    /// Installed with Homebrew (`brew install --cask`), so it is updated with Homebrew too.
    var isHomebrew: Bool { get }
}
