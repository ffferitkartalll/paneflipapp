import Foundation

extension SnapTrigger {
    public struct Key: Codable, Equatable {
        public let code: Int
        public let name: String

        public init(code: Int, name: String) {
            self.code = code
            self.name = name
        }
    }
}
