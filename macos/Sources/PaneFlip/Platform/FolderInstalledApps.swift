import Foundation

/// The apps of the usual application folders and of the folders inside them (a vendor's folder, the web apps a browser makes).
struct FolderInstalledApps: InstalledAppListing {
    private let folders: [String]

    init(folders: [String] = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]) { self.folders = folders }

    func apps() -> [InstalledApp] {
        var seen = Set<String>()
        var found: [InstalledApp] = []
        for folder in folders {
            // Two levels: the folder's own apps and those in its folders; an app's insides are not searched.
            let walk = FileManager.default.enumerator(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            var urls: [URL] = []
            while let url = walk?.nextObject() as? URL {
                if walk?.level ?? 0 > 2 { walk?.skipDescendants() } else if url.pathExtension == "app" { urls.append(url) }
            }
            for url in urls {
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
