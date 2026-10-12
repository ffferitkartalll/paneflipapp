import AppKit
import CoreText

/// Builds a small colour font (sbix bitmaps) in memory: one glyph per app icon, at private-use code points. An icon
/// put into the text of a segment is part of the text, so the system control (Liquid Glass lens included) treats it
/// like the name. The font is registered for this process only and rebuilt when a new icon appears.
final class IconFont {
    private(set) var codePoints: [String: UInt32] = [:]
    private var images: [String: Data] = [:]      // key → PNG
    private var generation = 0
    private var registered: URL?
    private(set) var fontName: String?

    static let bitmapSize = 144
    static let ppem = 100
    static let advance = 1500   // font units; 1000 per em, so an icon is 1.5 em wide

    /// A font for a control: `base` that falls back to the icon glyphs.
    func font(basedOn base: NSFont) -> NSFont? {
        guard let name = fontName else { return nil }
        let cascade = [CTFontDescriptorCreateWithNameAndSize(name as CFString, base.pointSize)]
        let descriptor = base.fontDescriptor.addingAttributes([.cascadeList: cascade])
        return NSFont(descriptor: descriptor, size: base.pointSize)
    }

    /// Text width where icon characters count as the glyph's real advance, whatever font the text is measured in.
    static func width(of text: String, font: NSFont) -> CGFloat {
        var width: CGFloat = 0
        var plain = ""
        func flush() { width += (plain as NSString).size(withAttributes: [.font: font]).width; plain = "" }
        for scalar in text.unicodeScalars {
            if (0xE000..<0xF900).contains(scalar.value) { flush(); width += font.pointSize * CGFloat(advance) / 1000 }
            else { plain.unicodeScalars.append(scalar) }
        }
        flush()
        return width.rounded(.up)
    }
    /// `name` cut at the end with an ellipsis until it is no wider than `room`; unchanged when it already fits.
    static func fitting(_ name: String, in room: CGFloat, font: NSFont) -> String {
        guard width(of: name, font: font) > room else { return name }
        var cut = name
        while !cut.isEmpty, width(of: cut + "…", font: font) > room { cut.removeLast() }
        return cut + "…"
    }

    /// App → glyph table: bundle identifier → an SF Symbol name, or `system:<name>` for a system icon file.
    /// Apps that are not listed get a shape taken from their own icon.
    private let glyphs: [String: String]
    private let brands: BrandGlyphSource
    private var brandVersion = 0

    init(brands: BrandGlyphSource) {
        self.brands = brands
        let url = Bundle.main.url(forResource: "AppGlyphs", withExtension: "json")
        glyphs = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    /// Changes whenever a brand glyph arrives from the network; titles built before that must be built again.
    var revision: Int { brands.version }

    /// Forgets the pictures made so far when a brand glyph has arrived. Call before building titles, never during.
    func syncBrands() {
        guard brandVersion != brands.version else { return }
        brandVersion = brands.version
        codePoints = [:]
        images = [:]
    }

    /// A single-colour picture for an app: the system's own glyph from the table, else a brand glyph by the app's name.
    private func glyph(bundleID: String, appName: String) -> NSImage? {
        guard let name = glyphs[bundleID] else { return brands.glyph(forApp: appName) }
        if name.hasPrefix("system:") {
            let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/\(name.dropFirst(7)).icns"
            return NSImage(contentsOfFile: path)
        }
        let size = CGFloat(Self.bitmapSize)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
    }

    /// The picture of an app as a single-coloured bitmap: the system's glyph when there is one, else its icon's shape.
    private func rendered(bundleID: String, appName: String, icon: NSImage, size: Int) -> NSBitmapImageRep {
        guard let glyph = glyph(bundleID: bundleID, appName: appName), glyph.size.width > 0, glyph.size.height > 0 else { return Self.template(icon, size: size) }
        let rep = Self.blank(size)
        // Aspect-fit into 80 % of the square, like the symbols of the system's tabs.
        let box = CGFloat(size) * 0.8
        let scale = min(box / glyph.size.width, box / glyph.size.height)
        let area = NSRect(x: (CGFloat(size) - glyph.size.width * scale) / 2, y: (CGFloat(size) - glyph.size.height * scale) / 2,
                          width: glyph.size.width * scale, height: glyph.size.height * scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        glyph.draw(in: area)
        NSColor.white.set()
        area.fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func blank(_ size: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    }

    /// The same picture as an image, for the labels that slide while the order changes.
    func image(bundleID: String, appName: String, icon: NSImage, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rendered(bundleID: bundleID, appName: appName, icon: icon, size: Int(size) * 4))
        return image
    }

    /// The app icon reduced to its foreground shape, drawn in white: the most common colour is taken as the
    /// background and what differs from it stays, so a glyph on a coloured tile becomes a plain symbol.
    private static func template(_ icon: NSImage, size: Int) -> NSBitmapImageRep {
        let rep = blank(size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let pixels = rep.bitmapData!, stride = rep.bytesPerRow
        func rgb(_ p: UnsafeMutablePointer<UInt8>) -> (CGFloat, CGFloat, CGFloat) {
            let a = max(CGFloat(p[3]), 1)   // un-premultiply
            return (min(1, CGFloat(p[0]) / a), min(1, CGFloat(p[1]) / a), min(1, CGFloat(p[2]) / a))
        }
        var histogram: [Int: Int] = [:]
        for row in 0..<size { for column in 0..<size {
            let p = pixels + row * stride + column * 4
            guard p[3] > 240 else { continue }
            let (r, g, b) = rgb(p)
            histogram[Int(r * 7.99) << 6 | Int(g * 7.99) << 3 | Int(b * 7.99), default: 0] += 1
        } }
        let key = histogram.max { $0.value < $1.value }?.key ?? 0
        let back = (CGFloat(key >> 6 & 7) / 7, CGFloat(key >> 3 & 7) / 7, CGFloat(key & 7) / 7)
        // First pass: how far each point is from the background colour (0...1), skipping the tile's own rim.
        var shape = [CGFloat](repeating: 0, count: size * size), outline = shape
        var covered = 0.0, total = 0.0
        let rim = max(3, size / 36)
        func alphaAt(_ row: Int, _ column: Int) -> CGFloat {
            guard (0..<size).contains(row), (0..<size).contains(column) else { return 0 }
            return CGFloat(pixels[row * stride + column * 4 + 3]) / 255
        }
        for row in 0..<size { for column in 0..<size {
            let p = pixels + row * stride + column * 4
            let alpha = CGFloat(p[3]) / 255
            guard alpha > 0 else { continue }
            let (r, g, b) = rgb(p)
            let distance = ((r - back.0) * (r - back.0) + (g - back.1) * (g - back.1) + (b - back.2) * (b - back.2)).squareRoot()
            let t = min(1, max(0, (distance - 0.2) / 0.3))
            let inside = alphaAt(row - rim, column) > 0.5 && alphaAt(row + rim, column) > 0.5
                && alphaAt(row, column - rim) > 0.5 && alphaAt(row, column + rim) > 0.5
            let luminance = (0.299 * r + 0.587 * g + 0.114 * b)
            shape[row * size + column] = inside ? alpha * t * t * (3 - 2 * t) : 0
            outline[row * size + column] = inside ? alpha * min(1, max(0.15, 1.1 - luminance)) : 0
            total += alpha; covered += shape[row * size + column]
        } }
        // An icon that is mostly one shape on a plain tile keeps the shape; a many-coloured picture keeps its dark detail inside that shape.
        let result = covered / max(total, 1) > 0.5 ? zip(shape, outline).map { $0 * $1 } : shape
        for row in 0..<size { for column in 0..<size {
            let p = pixels + row * stride + column * 4
            let opacity = result[row * size + column]
            p[0] = UInt8(opacity * 255); p[1] = p[0]; p[2] = p[0]   // white, premultiplied
            p[3] = UInt8(opacity * 255)
        } }
        return rep
    }

    /// Returns the private-use character for an icon key, adding the icon when it is new.
    func character(for key: String, bundleID: String, appName: String, icon: NSImage) -> Character {
        if let cp = codePoints[key] { return Character(UnicodeScalar(cp)!) }
        let cp = 0xE000 + UInt32(codePoints.count)
        codePoints[key] = cp
        images[key] = rendered(bundleID: bundleID, appName: appName, icon: icon, size: Self.bitmapSize).representation(using: .png, properties: [:])!
        rebuild()
        return Character(UnicodeScalar(cp)!)
    }

    private func rebuild() {
        generation += 1
        let name = "PaneFlipIcons\(generation)"
        let keys = codePoints.sorted { $0.value < $1.value }.map(\.key)
        let data = Self.font(named: name, pngs: keys.map { images[$0]! })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).ttf")
        try? data.write(to: url)
        if let old = registered { CTFontManagerUnregisterFontsForURL(old as CFURL, .process, nil); try? FileManager.default.removeItem(at: old) }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { registered = url; fontName = name }
    }

    // MARK: TrueType writer

    private static func font(named name: String, pngs: [Data]) -> Data {
        let numGlyphs = pngs.count + 1
        func u16(_ v: Int) -> Data { Data([UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]) }
        func u32(_ v: Int) -> Data { Data([UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]) }
        func pad(_ d: Data) -> Data { var d = d; while d.count % 4 != 0 { d.append(0) }; return d }

        var head = Data()
        head += u32(0x00010000) + u32(0x00010000) + u32(0) + u32(0x5F0F3CF5) + u16(0x000B) + u16(1000)
        head += Data(count: 16)                                   // created, modified
        head += u16(0) + u16(-200 & 0xFFFF) + u16(advance) + u16(800)
        head += u16(0) + u16(8) + u16(2) + u16(0) + u16(0)        // macStyle, lowestRecPPEM, direction, locaFormat(short), glyphDataFormat

        var hhea = Data()
        hhea += u32(0x00010000) + u16(800) + u16(-200 & 0xFFFF) + u16(0) + u16(advance) + u16(0) + u16(0) + u16(advance)
        hhea += u16(1) + u16(0) + u16(0) + Data(count: 8) + u16(0) + u16(numGlyphs)

        var maxp = u32(0x00010000) + u16(numGlyphs)
        maxp += Data(count: 26)

        var hmtx = Data()
        for _ in 0..<numGlyphs { hmtx += u16(advance) + u16(0) }

        let loca = Data(count: (numGlyphs + 1) * 2)
        let glyf = Data(count: 4)

        // cmap, format 4: one contiguous range
        let first = 0xE000, last = 0xE000 + pngs.count - 1
        var sub = Data()
        sub += u16(4) + u16(32) + u16(0) + u16(4) + u16(4) + u16(1) + u16(0)
        sub += u16(last) + u16(0xFFFF) + u16(0) + u16(first) + u16(0xFFFF)
        sub += u16((1 - first) & 0xFFFF) + u16(1) + u16(0) + u16(0)
        var cmap = u16(0) + u16(1) + u16(3) + u16(1) + u32(12)
        cmap += sub

        func nameRecord(_ id: Int, _ s: String) -> (Data, Data) {
            let str = Data(s.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] })
            return (u16(3) + u16(1) + u16(0x409) + u16(id) + u16(str.count), str)
        }
        let strings = [(1, name), (2, "Regular"), (4, name), (6, name)]
        var nameTable = u16(0) + u16(strings.count) + u16(6 + 12 * strings.count)
        var storage = Data()
        for (id, s) in strings {
            let (rec, str) = nameRecord(id, s)
            nameTable += rec.prefix(8) + u16(str.count) + u16(storage.count)
            storage += str
        }
        nameTable += storage

        var os2 = u16(4) + u16(500) + u16(400) + u16(5) + u16(0)
        os2 += Data(count: 20)                                   // subscript/superscript/strikeout sizes
        os2 += u16(0) + u16(0) + Data(count: 10) + Data(count: 16)  // family class, panose, unicode ranges
        os2 += Data("PFIC".utf8) + u16(0x40) + u16(first) + u16(last)
        os2 += u16(800) + u16(-200 & 0xFFFF) + u16(0) + u16(800) + u16(200)
        os2 += u32(0) + u32(0) + u16(0) + u16(0) + u16(0) + u16(0) + u16(0)

        let post = u32(0x00030000) + Data(count: 28)

        // sbix: one strike
        var sbix = u16(1) + u16(1) + u32(1) + u32(12)
        var strike = u16(ppem) + u16(72)
        let headerLen = 4 + 4 * (numGlyphs + 1)
        var offsets: [Int] = []
        var body = Data()
        offsets.append(headerLen)                                // .notdef: empty
        for png in pngs {
            offsets.append(headerLen + body.count)
            // Bitmap bottom edge below the baseline: centres the icon on the text's cap height.
            body += u16(0) + u16(-36 & 0xFFFF) + Data("png ".utf8) + png
        }
        offsets.append(headerLen + body.count)
        for o in offsets { strike += u32(o) }
        // offsets[0] == offsets[1] when .notdef is empty is correct: glyph 0 has zero length
        sbix += strike + body

        let tables: [(String, Data)] = [("OS/2", os2), ("cmap", cmap), ("glyf", glyf), ("head", head), ("hhea", hhea), ("hmtx", hmtx),
                                        ("loca", loca), ("maxp", maxp), ("name", nameTable), ("post", post), ("sbix", sbix)]
        let n = tables.count
        var searchRange = 1, entrySelector = 0
        while searchRange * 2 <= n { searchRange *= 2; entrySelector += 1 }
        var out = u32(0x00010000) + u16(n) + u16(searchRange * 16) + u16(entrySelector) + u16(n * 16 - searchRange * 16)
        var offset = 12 + 16 * n
        var directory = Data(), payload = Data()
        var headOffset = 0
        for (tag, table) in tables {
            let padded = pad(table)
            var sum: UInt32 = 0
            for i in stride(from: 0, to: padded.count, by: 4) {
                sum = sum &+ (UInt32(padded[i]) << 24 | UInt32(padded[i + 1]) << 16 | UInt32(padded[i + 2]) << 8 | UInt32(padded[i + 3]))
            }
            if tag == "head" { headOffset = payload.count }
            directory += Data(tag.utf8) + u32(Int(sum)) + u32(offset) + u32(table.count)
            payload += padded
            offset += padded.count
        }
        out += directory + payload
        // whole-file checksum into head.checkSumAdjustment
        var total: UInt32 = 0
        var bytes = out
        while bytes.count % 4 != 0 { bytes.append(0) }
        for i in stride(from: 0, to: bytes.count, by: 4) {
            total = total &+ (UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3]))
        }
        let adjust = 0xB1B0AFBA &- total
        let at = 12 + 16 * n + headOffset + 8
        out.replaceSubrange(at..<at + 4, with: u32(Int(adjust)))
        return out
    }
}
