/// A version number such as `1.0` or `v1.2.3`, compared number by number (`1.0` equals `1.0.0`).
public struct AppVersion: Comparable, CustomStringConvertible {
    private let numbers: [Int]

    /// Nil when the text is not dot-separated numbers (a leading `v` is allowed).
    public init?(_ text: String) {
        let digits = text.first == "v" || text.first == "V" ? text.dropFirst() : Substring(text)
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        numbers = parts.compactMap { $0 }
    }

    public var description: String { numbers.map(String.init).joined(separator: ".") }

    public static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        for i in 0..<max(a.numbers.count, b.numbers.count) {
            let x = i < a.numbers.count ? a.numbers[i] : 0, y = i < b.numbers.count ? b.numbers[i] : 0
            if x != y { return x < y }
        }
        return false
    }
}
