import AppKit

/// Brand glyphs from a public icon set, fetched when an app first needs one and kept on disk afterwards. Without a
/// network the caller simply gets nothing and draws its own picture.
final class CDNBrandGlyphs: BrandGlyphSource {
    /// The release is pinned: an icon removed upstream later does not change what this build asks for.
    static let release = "16.35.0"
    /// A failed request is tried again after this long, up to `maxAttempts` times.
    private let retryAfter: TimeInterval
    private static let maxAttempts = 3

    /// Changes when a glyph arrives and when the switch is flipped, so what was drawn before is drawn again.
    var version: Int { arrivals + (isEnabled() ? 1_000_000 : 0) }
    private var arrivals = 0
    private var attempts: [String: Int] = [:]
    private var images: [String: NSImage] = [:]
    private var failed: [String: Date] = [:]
    /// Icons the set is known not to have (404), so the disk is not read again for them.
    private var absent: Set<String> = []
    private var pending: Set<String> = []
    private let folder: URL
    private let session: URLSession
    private let isEnabled: () -> Bool

    init(session: URLSession = .shared, folder: URL? = nil, retryAfter: TimeInterval = 300, isEnabled: @escaping () -> Bool = { true }) {
        self.session = session
        self.isEnabled = isEnabled
        self.retryAfter = retryAfter
        self.folder = folder ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PaneFlip/BrandGlyphs/\(Self.release)", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
    }

    /// The names an app may have in the set: the whole name, then its first word when the rest is only a common
    /// ending ("Brand Desktop" → brand, but "Brand Player" is not the brand).
    static func slugs(forApp name: String) -> [String] {
        let words = name.split(separator: " ").map { $0.lowercased().filter { $0.isLetter || $0.isNumber } }.filter { !$0.isEmpty }
        let endings: Set<String> = ["desktop", "app", "beta", "helper", "warp"]
        guard let first = words.first else { return [] }
        return [words.joined()] + (words.count > 1 && words.dropFirst().allSatisfy(endings.contains) ? [first] : [])
    }

    func glyph(forApp name: String) -> NSImage? {
        for slug in Self.slugs(forApp: name) { if let image = image(slug: slug) { return image } }
        return nil
    }

    private func image(slug: String) -> NSImage? {
        if let image = images[slug] { return image }
        if absent.contains(slug) { return nil }
        let file = folder.appendingPathComponent("\(slug).svg")
        if let data = try? Data(contentsOf: file) {
            // An empty file records that the set has no such icon.
            guard !data.isEmpty, let image = Self.image(from: data) else { absent.insert(slug); return nil }
            images[slug] = image
            return image
        }
        if !isEnabled() || pending.contains(slug) || failed[slug].map({ Date().timeIntervalSince($0) < retryAfter }) == true { return nil }
        pending.insert(slug)
        let url = URL(string: "https://cdn.jsdelivr.net/npm/simple-icons@\(Self.release)/icons/\(slug).svg")!
        session.dataTask(with: url) { [weak self] data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode
            DispatchQueue.main.async { self?.received(slug: slug, data: data, status: status, file: file) }
        }.resume()
        return nil
    }

    /// The picture of an SVG, with its arc flags spelled out so the system's SVG reader does not warn about them.
    private static func image(from data: Data) -> NSImage? {
        String(data: data, encoding: .utf8).flatMap { NSImage(data: Data(SVGArcFlags.normalized($0).utf8)) }
    }

    private func received(slug: String, data: Data?, status: Int?, file: URL) {
        pending.remove(slug)
        if status == 404 {
            try? Data().write(to: file)
            absent.insert(slug)
        } else if status == 200, let data, data.starts(with: Data("<svg".utf8)), let image = Self.image(from: data) {
            try? data.write(to: file)
            images[slug] = image
            attempts[slug] = nil
            arrivals += 1
        } else {
            failed[slug] = Date()
            attempts[slug, default: 0] += 1
            guard attempts[slug]! < Self.maxAttempts else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) { [weak self] in
                self?.failed[slug] = nil
                _ = self?.image(slug: slug)
            }
        }
    }
}
