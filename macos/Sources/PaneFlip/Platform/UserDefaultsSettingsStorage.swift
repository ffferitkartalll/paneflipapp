import Foundation
import PaneFlipCore

/// Keeps the settings in UserDefaults under the keys earlier versions already used.
struct UserDefaultsSettingsStorage: SettingsStorage {
    private let defaults: UserDefaults

    private static let shortcuts: [(String, WritableKeyPath<SettingsValues, SnapTrigger>)] = [
        ("nextWindowShortcut", \.nextWindowShortcut), ("previousWindowShortcut", \.previousWindowShortcut),
        ("scrollRightShortcut", \.scrollRightShortcut), ("scrollLeftShortcut", \.scrollLeftShortcut), ("undoWindowShortcut", \.undoWindowShortcut), ("closeWindowUndoNoticeShortcut", \.closeWindowUndoNoticeShortcut),
        ("zoneUpShortcut", \.zoneUpShortcut), ("zoneLeftShortcut", \.zoneLeftShortcut),
        ("zoneDownShortcut", \.zoneDownShortcut), ("zoneRightShortcut", \.zoneRightShortcut),
    ]

    /// The defaults some shortcuts had in earlier versions: a stored one that equals its former default was never changed, and is not kept.
    private static let formerDefaults: [String: SnapTrigger] = [
        "zoneUpShortcut": .formerZoneUp, "zoneLeftShortcut": .formerZoneLeft, "zoneDownShortcut": .formerZoneDown, "zoneRightShortcut": .formerZoneRight,
    ]

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Settings that earlier versions had and this one does not: loading forgets them.
    // "deskArrangement" held the places in points; the places are in millimetres now (the displays are set again).
    private static let removedKeys = ["scrollGestureEnabled", "edgeScrollEnabled", "deskArrangement"]

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
        v.sendToZoneKeys = defaults.data(forKey: "sendToZoneKeys").flatMap { try? JSONDecoder().decode(SnapTrigger.self, from: $0) } ?? v.sendToZoneKeys
        v.deskArrangement = defaults.data(forKey: "deskArrangementMillimetres").flatMap { try? JSONDecoder().decode(DeskArrangement.self, from: $0) } ?? v.deskArrangement
        v.trackpadMethod = defaults.string(forKey: "trackpadMethod").flatMap(TrackpadMethod.init(rawValue:)) ?? v.trackpadMethod
        v.trackpadSpeed = defaults.object(forKey: "trackpadSpeed") as? Double ?? v.trackpadSpeed
        for (key, path) in Self.shortcuts {
            if let trigger = defaults.data(forKey: key).flatMap({ try? JSONDecoder().decode(SnapTrigger.self, from: $0) }), trigger != Self.formerDefaults[key] { v[keyPath: path] = trigger }
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
        defaults.set(try? JSONEncoder().encode(v.sendToZoneKeys), forKey: "sendToZoneKeys")
        for (key, path) in Self.shortcuts { defaults.set(try? JSONEncoder().encode(v[keyPath: path]), forKey: key) }
        defaults.set(try? JSONEncoder().encode(v.deskArrangement), forKey: "deskArrangementMillimetres")
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
