import Foundation
import PaneFlipCore

/// Keeps the settings in UserDefaults under the keys earlier versions already used.
struct UserDefaultsSettingsStorage: SettingsStorage {
    private let defaults: UserDefaults

    private static let shortcuts: [(String, WritableKeyPath<SettingsValues, SnapTrigger>)] = [
        ("nextWindowShortcut", \.nextWindowShortcut), ("previousWindowShortcut", \.previousWindowShortcut),
        ("scrollRightShortcut", \.scrollRightShortcut), ("scrollLeftShortcut", \.scrollLeftShortcut),
        ("zoneUpShortcut", \.zoneUpShortcut), ("zoneLeftShortcut", \.zoneLeftShortcut),
        ("zoneDownShortcut", \.zoneDownShortcut), ("zoneRightShortcut", \.zoneRightShortcut),
    ]

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Settings that earlier versions had and this one does not: loading forgets them.
    private static let removedKeys = ["scrollGestureEnabled", "edgeScrollEnabled"]

    func load() -> SettingsValues {
        Self.removedKeys.forEach(defaults.removeObject(forKey:))
        var v = SettingsValues()
        v.placementEnabled = defaults.object(forKey: "placementEnabled") as? Bool ?? v.placementEnabled
        v.gap = defaults.object(forKey: "gap") as? Double ?? v.gap
        v.restoreSizeOnLeave = defaults.object(forKey: "restoreSizeOnLeave") as? Bool ?? v.restoreSizeOnLeave
        v.edgeMargin = defaults.object(forKey: "edgeMargin") as? Double ?? v.edgeMargin
        v.minZoneSize = defaults.object(forKey: "minZoneSize") as? Double ?? v.minZoneSize
        v.zoneNavigationEnabled = defaults.object(forKey: "zoneNavigationEnabled") as? Bool ?? v.zoneNavigationEnabled
        v.zoneNavigationBeyondEdges = defaults.object(forKey: "zoneNavigationBeyondEdges") as? Bool ?? v.zoneNavigationBeyondEdges
        v.fetchBrandIcons = defaults.object(forKey: "fetchBrandIcons") as? Bool ?? v.fetchBrandIcons
        v.snapTrigger = defaults.data(forKey: "snapTrigger").flatMap { try? JSONDecoder().decode(SnapTrigger.self, from: $0) } ?? v.snapTrigger
        v.windowScrollKeys = defaults.data(forKey: "windowScrollKeys").flatMap { try? JSONDecoder().decode(SnapTrigger.self, from: $0) } ?? v.windowScrollKeys
        v.stripScrollKeys = defaults.data(forKey: "stripScrollKeys").flatMap { try? JSONDecoder().decode(SnapTrigger.self, from: $0) } ?? v.stripScrollKeys
        v.trackpadMethod = defaults.string(forKey: "trackpadMethod").flatMap(TrackpadMethod.init(rawValue:)) ?? v.trackpadMethod
        v.trackpadSpeed = defaults.object(forKey: "trackpadSpeed") as? Double ?? v.trackpadSpeed
        for (key, path) in Self.shortcuts {
            if let trigger = defaults.data(forKey: key).flatMap({ try? JSONDecoder().decode(SnapTrigger.self, from: $0) }) { v[keyPath: path] = trigger }
        }
        v.ignoredApps = defaults.stringArray(forKey: "ignoredApps") ?? v.ignoredApps
        v.overflowZonesEnabled = defaults.object(forKey: "overflowZonesEnabled") as? Bool ?? v.overflowZonesEnabled
        v.language = defaults.string(forKey: "appLanguage") ?? v.language
        return v
    }

    func save(_ v: SettingsValues) {
        defaults.set(v.placementEnabled, forKey: "placementEnabled")
        defaults.set(v.gap, forKey: "gap")
        defaults.set(v.restoreSizeOnLeave, forKey: "restoreSizeOnLeave")
        defaults.set(v.edgeMargin, forKey: "edgeMargin")
        defaults.set(v.minZoneSize, forKey: "minZoneSize")
        defaults.set(v.zoneNavigationEnabled, forKey: "zoneNavigationEnabled")
        defaults.set(v.zoneNavigationBeyondEdges, forKey: "zoneNavigationBeyondEdges")
        defaults.set(v.trackpadMethod.rawValue, forKey: "trackpadMethod")
        defaults.set(v.fetchBrandIcons, forKey: "fetchBrandIcons")
        defaults.set(try? JSONEncoder().encode(v.snapTrigger), forKey: "snapTrigger")
        defaults.set(v.trackpadSpeed, forKey: "trackpadSpeed")
        defaults.set(try? JSONEncoder().encode(v.windowScrollKeys), forKey: "windowScrollKeys")
        defaults.set(try? JSONEncoder().encode(v.stripScrollKeys), forKey: "stripScrollKeys")
        for (key, path) in Self.shortcuts { defaults.set(try? JSONEncoder().encode(v[keyPath: path]), forKey: key) }
        defaults.set(v.ignoredApps, forKey: "ignoredApps")
        defaults.set(v.overflowZonesEnabled, forKey: "overflowZonesEnabled")
        // The system reads the app's language from `AppleLanguages` when the app starts; without it the system's order
        // is used. System Settings writes that key too (a language chosen for this app there), so it is touched only
        // when the choice here changed.
        guard (defaults.string(forKey: "appLanguage") ?? SettingsValues.systemLanguage) != v.language else { return }
        defaults.set(v.language, forKey: "appLanguage")
        if v.language == SettingsValues.systemLanguage { defaults.removeObject(forKey: "AppleLanguages") }
        else { defaults.set([v.language], forKey: "AppleLanguages") }
    }
}
