import Foundation

/// SVG minifiers write the two flags of an arc as single characters with no separator ("a1 1 0 00-1 1"). That is
/// valid SVG, but the system's SVG reader warns about it ("A/a command was given the wrong number of floats") and
/// may misread the arc. This spells every number and flag out with spaces.
enum SVGArcFlags {
    /// `svg` with the path data of every `d="…"` attribute written with spaces between all numbers and flags.
    static func normalized(_ svg: String) -> String {
        guard let pattern = try? NSRegularExpression(pattern: #"\bd="([^"]*)""#) else { return svg }
        var result = svg
        let ns = svg as NSString
        for match in pattern.matches(in: svg, range: NSRange(location: 0, length: ns.length)).reversed() {
            let path = ns.substring(with: match.range(at: 1))
            result = (result as NSString).replacingCharacters(in: match.range(at: 1), with: normalizedPath(path))
        }
        return result
    }

    /// "M1.5.5a2 2 0 00-1 1" → "M 1.5 .5 a 2 2 0 0 0 -1 1"
    static func normalizedPath(_ d: String) -> String {
        let chars = Array(d)
        var tokens: [String] = []
        var i = 0
        var inArc = false
        var argument = 0
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "," || c.isNewline { i += 1; continue }
            if c.isLetter {
                tokens.append(String(c))
                inArc = c == "a" || c == "A"
                argument = 0
                i += 1
                continue
            }
            let start = i
            if inArc, argument % 7 == 3 || argument % 7 == 4 {
                i += 1   // a flag is one character, 0 or 1
            } else {
                if c == "-" || c == "+" { i += 1 }
                var dot = false
                while i < chars.count {
                    let ch = chars[i]
                    if ch.isNumber { i += 1 }
                    else if ch == ".", !dot { dot = true; i += 1 }
                    else if ch == "e" || ch == "E" {
                        i += 1
                        if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
                    } else { break }
                }
                if i == start { i += 1 }   // not part of a number: skip it so the loop always ends
            }
            tokens.append(String(chars[start..<i]))
            argument += 1
        }
        return tokens.joined(separator: " ")
    }
}
