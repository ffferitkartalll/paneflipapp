import Foundation

/// How stacked windows are labelled on the pill.
public enum TabNaming {
    public struct Entry {
        public let appName: String
        public let title: String

        public init(appName: String, title: String) {
            self.appName = appName
            self.title = title
        }
    }

    /// The app name alone when the app has one window in the zone; "App | Window title" when it has several.
    /// Many apps end every window title with their own name ("Page - App"); that part is left out.
    public static func displayNames(for entries: [Entry]) -> [String] {
        entries.map { entry in
            let shared = entries.filter { $0.appName == entry.appName }.count > 1
            let title = withoutAppName(entry.title, appName: entry.appName)
            guard shared, !title.isEmpty, title != entry.appName else { return entry.appName }
            return "\(entry.appName) | \(title)"
        }
    }

    /// "Page - App" → "Page" (the separator may be a hyphen, en dash or em dash with spaces around it).
    static func withoutAppName(_ title: String, appName: String) -> String {
        for separator in [" - ", " \u{2013} ", " \u{2014} "] where title.hasSuffix(separator + appName) {
            return String(title.dropLast(separator.count + appName.count))
        }
        return title
    }
}
