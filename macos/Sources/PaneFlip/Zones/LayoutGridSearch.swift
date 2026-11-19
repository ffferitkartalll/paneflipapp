import Foundation
import Observation

/// What the search bar of the grid of a whole layout shows, the same on every display: the text typed and how many zones and windows the grid has.
@Observable
final class LayoutGridSearch {
    var query = ""
    var zones = 0
    var windows = 0
    /// The text was changed in the bar (the keys, a paste, an input method), and the button that ends the search was pressed.
    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored var onClear: () -> Void = {}
    /// Count up when the bar is to take the keys (a key came while it did not have them) and when it is to let them go (the search ended).
    var focusToken = 0
    var blurToken = 0
}
