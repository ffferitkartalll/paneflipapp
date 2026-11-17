import Foundation
import PaneFlipCore

extension DisplayScene {
    /// The name a scene has until it is renamed, by its place among the scenes: "Default" for the first, then "Scene 2", "Scene 3"…
    func defaultTitle(in scenes: [DisplayScene]) -> String {
        let number = (scenes.firstIndex { $0.id == id } ?? scenes.count) + 1
        return number == 1 ? String(localized: "Default") : String(localized: "Scene \(number)")
    }

    func title(in scenes: [DisplayScene]) -> String { name.isEmpty ? defaultTitle(in: scenes) : name }
}
