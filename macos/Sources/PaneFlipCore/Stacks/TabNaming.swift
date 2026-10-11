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

    /// The app name alone when the app has one window in the zone; "App — Window title" when it has several.
    public static func displayNames(for entries: [Entry]) -> [String] {
        entries.map { entry in
            let shared = entries.filter { $0.appName == entry.appName }.count > 1
            guard shared, !entry.title.isEmpty, entry.title != entry.appName else { return entry.appName }
            return "\(entry.appName) — \(entry.title)"
        }
    }
}
