import Foundation

/// Homebrew keeps every cask it installed in its Caskroom, under the cask's name.
struct CaskroomInstallSource: InstallSourceDetecting {
    let cask: String

    var isHomebrew: Bool {
        ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"].contains { FileManager.default.fileExists(atPath: "\($0)/\(cask)") }
    }
}
