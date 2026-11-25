import AppKit

/// Makes the single-colour picture of an app's glyph for the cards (the system's glyph table, a brand glyph, or the shape of the app's icon) and keeps the pictures made.
final class GlyphImages {
    private var images: [String: Data] = [:]      // key → PNG

    static let bitmapSize = 144
    /// A system glyph is aspect-fit into this share of its square picture, like the symbols of the system's tabs.
    static let glyphShare: CGFloat = 0.8

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
        let box = CGFloat(size) * Self.glyphShare
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

    /// The picture the island draws for an app, as an image `size` points wide: the very bitmap of the font's glyph,
    /// so the settings and the island cannot differ. Made (and added to the font) when it does not exist yet.
    func image(bundleID: String, appName: String, icon: NSImage, size: CGFloat) -> NSImage {
        let key = bundleID.isEmpty ? appName : bundleID
        // Only the bitmap: registering the glyph rebuilds the whole font on the main thread, which the island does when it needs the character.
        if images[key] == nil { images[key] = rendered(bundleID: bundleID, appName: appName, icon: icon, size: Self.bitmapSize).representation(using: .png, properties: [:])! }
        let bitmap = images[key].flatMap(NSImage.init(data:)) ?? NSImage()
        // Drawn when it is shown, at the pixels it is shown in and with the best filter: the bitmap is several times larger than the icon, and scaled down
        // by the view alone it comes out with hard, jagged edges.
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            bitmap.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
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
}
