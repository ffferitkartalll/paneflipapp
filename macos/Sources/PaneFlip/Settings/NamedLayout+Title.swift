import Foundation
import PaneFlipCore

extension NamedLayout {
    /// The name a layout has until it is renamed, by its place among the layouts of its display: "Default" for the first, then "Layout 2", "Layout 3"…
    /// It is made here, so it follows the app's language.
    func defaultTitle(in layouts: [NamedLayout]) -> String {
        let number = (layouts.firstIndex { $0.id == id } ?? layouts.count) + 1
        return number == 1 ? String(localized: "Default") : String(localized: "Layout \(number)")
    }

    /// What the layout is called on screen: the name the user gave it, else its default name.
    func title(in layouts: [NamedLayout]) -> String { name.isEmpty ? defaultTitle(in: layouts) : name }
}
