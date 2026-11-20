import Foundation

/// The apps of the usual application folders.
struct FolderInstalledApps: InstalledAppListing {
    private static let folders = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]

    func apps() -> [InstalledApp] {
        var seen = Set<String>()
        var found: [InstalledApp] = []
        for folder in Self.folders {
            let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, id != Bundle.main.bundleIdentifier, !seen.contains(id) else { continue }
                let info = bundle.infoDictionary ?? [:]
                // Helpers and agents have no icon in the Dock.
                if info["LSUIElement"] as? Bool == true || info["LSUIElement"] as? String == "1" || info["LSBackgroundOnly"] as? Bool == true { continue }
                seen.insert(id)
                let shown = FileManager.default.displayName(atPath: url.path)
                found.append(InstalledApp(bundleID: id, name: shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown))
            }
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
