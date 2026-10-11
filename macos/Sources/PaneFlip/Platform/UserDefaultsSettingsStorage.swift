import Foundation
import PaneFlipCore

/// Keeps the settings in UserDefaults under the keys earlier versions already used.
struct UserDefaultsSettingsStorage: SettingsStorage {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> SettingsValues {
        var v = SettingsValues()
        v.placementEnabled = defaults.object(forKey: "placementEnabled") as? Bool ?? v.placementEnabled
        v.stackingEnabled = defaults.object(forKey: "stackingEnabled") as? Bool ?? v.stackingEnabled
        v.gap = defaults.object(forKey: "gap") as? Double ?? v.gap
        v.minZoneSize = defaults.object(forKey: "minZoneSize") as? Double ?? v.minZoneSize
        v.pillContent = defaults.string(forKey: "pillContent").flatMap(PillContent.init(rawValue:)) ?? v.pillContent
        v.snapTrigger = defaults.data(forKey: "snapTrigger").flatMap { try? JSONDecoder().decode(SnapTrigger.self, from: $0) } ?? v.snapTrigger
        return v
    }

    func save(_ v: SettingsValues) {
        defaults.set(v.placementEnabled, forKey: "placementEnabled")
        defaults.set(v.stackingEnabled, forKey: "stackingEnabled")
        defaults.set(v.gap, forKey: "gap")
        defaults.set(v.minZoneSize, forKey: "minZoneSize")
        defaults.set(v.pillContent.rawValue, forKey: "pillContent")
        defaults.set(try? JSONEncoder().encode(v.snapTrigger), forKey: "snapTrigger")
    }
}
