import CoreGraphics

/// How large a display's picture is drawn in the settings: as large as the display is in the desk map of the Displays tab, where all the displays side by side fill the width.
enum DeskScale {
    /// About the width of the desk map in the Displays tab.
    static let mapWidth: CGFloat = 620

    static func width(of screen: ScreenInfo, among screens: [ScreenInfo]) -> CGFloat {
        let total = DeskSpace.distinct(screens).map(\.deskSize.width).reduce(0, +)
        return total > 0 ? mapWidth * screen.deskSize.width / total : 230
    }
}
