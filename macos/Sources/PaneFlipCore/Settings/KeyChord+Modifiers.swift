import Foundation

extension KeyChord {
    public struct Modifiers: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let command = Modifiers(rawValue: 4)
        public static let shift = Modifiers(rawValue: 8)
    }
}
