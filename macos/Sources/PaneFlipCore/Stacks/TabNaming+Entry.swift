import Foundation

extension TabNaming {
    public struct Entry {
        public let appName: String
        public let title: String

        public init(appName: String, title: String) {
            self.appName = appName
            self.title = title
        }
    }
}
