import Foundation

/// Finds windows by what the person types, the best match first.
public enum WindowSearch {
    /// The places in `titles` of the windows that match `query`, best first (as many as match). Each word of the query (they are split at spaces, and may come in any order) has to be
    /// found in the title, or, less well, in `others` (the same place: the name of the app, for one). A title is better the nearer its words come to what was typed: it is that
    /// text, or it begins with it, or a word of it does, or it only has it inside a word; and, those being equal, the earlier it is found, the shorter the title, and the earlier
    /// it stands in the list. Case, accents, width and the dots of the Turkish I do not matter. Nothing matches an empty `query`.
    public static func matches(_ query: String, in titles: [String], others: [String] = []) -> [Int] {
        let words = fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        var ranked: [(place: Int, score: Score)] = []
        for place in titles.indices {
            let title = fold(titles[place]), other = others.indices.contains(place) ? fold(others[place]) : ""
            var tier = 0, position = Int.max, matched = true
            for word in words {
                if let hit = rank(of: word, in: title, whole: words.count == 1) {
                    tier += hit.tier
                    if word == words[0] { position = hit.position }
                } else if !other.isEmpty, let hit = rank(of: word, in: other, whole: false) {
                    tier += hit.tier + otherPenalty
                } else { matched = false; break }
            }
            if matched { ranked.append((place, Score(tier: tier, position: position, length: title.count, place: place))) }
        }
        return ranked.sorted { $0.score < $1.score }.map(\.place)
    }

    private static let otherPenalty = 4

    private struct Score: Comparable {
        let tier: Int, position: Int, length: Int, place: Int
        static func < (a: Score, b: Score) -> Bool {
            (a.tier, a.position, a.length, a.place) < (b.tier, b.position, b.length, b.place)
        }
    }

    /// How well `word` is found in `text` (both folded): 0 the whole text, 1 the beginning of it, 2 the beginning of a word of it, 3 inside a word; and where. Nil: not found.
    private static func rank(of word: String, in text: String, whole: Bool) -> (tier: Int, position: Int)? {
        if whole, text == word { return (0, 0) }
        if text.hasPrefix(word) { return (1, 0) }
        var start = text.startIndex, inside: Int?
        while let found = text.range(of: word, range: start..<text.endIndex) {
            let position = text.distance(from: text.startIndex, to: found.lowerBound)
            if found.lowerBound == text.startIndex || !text[text.index(before: found.lowerBound)].isLetterOrNumber { return (2, position) }
            if inside == nil { inside = position }
            start = text.index(after: found.lowerBound)
        }
        return inside.map { (3, $0) }
    }

    /// Text as it is compared: lower case, without accents, with the same width, and the Turkish dotted and dotless I as the plain one (a person typing the capital I of a name
    /// that begins with a dotted i must find it).
    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).replacingOccurrences(of: "ı", with: "i")
    }
}

private extension Character {
    var isLetterOrNumber: Bool { isLetter || isNumber }
}
