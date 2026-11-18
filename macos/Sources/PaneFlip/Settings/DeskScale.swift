import CoreGraphics

/// How large a display's picture is drawn in the settings: as large as the display is in the desk map of the Displays tab, where all the displays side by side fill the width (a lone display no taller than `loneHeight`).
enum DeskScale {
    /// About the width of the desk map in the Displays tab.
    static let mapWidth: CGFloat = 620

    /// How tall the picture of a lone display is drawn (it would fill the whole width of the window otherwise): its width follows from the display's shape.
    static let loneHeight: CGFloat = 162

    static func width(of screen: ScreenInfo, among screens: [ScreenInfo]) -> CGFloat {
        let distinct = DeskSpace.distinct(screens)
        let total = distinct.map(\.deskSize.width).reduce(0, +)
        let share = total > 0 ? mapWidth * screen.deskSize.width / total : 230
        // Only a lone display is held back: with several, their sizes to one another on the desk map stay as they are.
        return distinct.count == 1 ? min(share, loneHeight * screen.size.width / max(screen.size.height, 1)) : share
    }
}
