import CoreGraphics

/// A window's rounded corners show up in its picture as transparent pixels. Moving such a picture over other
/// content lets that content shine through the corners, so the corners are measured and filled in; the rounded edge
/// is then cut again once, around the zone. Done in one pass over one copy of the picture: this runs between a click
/// and the start of the slide.
enum WindowCorners {
    /// The picture with every transparent corner pixel given the colour of the nearest opaque pixel in its row, and
    /// the corner radius in pixels (0 when the corners are square, the picture is then returned as it is).
    static func squared(_ image: CGImage) -> (image: CGImage, radius: Int) {
        let width = image.width, height = image.height
        // Square corners (the corner pixel is opaque): nothing to measure, and no copy of the whole picture to make.
        if cornerAlpha(of: image) > 200 { return (image, 0) }
        // The picture's own colour space: re-drawing it in a plain device space would shift every colour, and the
        // picture would no longer match the window it stands in for.
        let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        // Rows padded to 64 bytes: the layer takes such a picture as it is, without copying it first.
        let rowBytes = (width * 4 + 63) / 64 * 64
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
              let base = context.data?.assumingMemoryBound(to: UInt8.self) else { return (image, 0) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // BGRA, the order the capture and the screen use: nothing is swapped on the way in or when the picture is put on screen. The alpha is the fourth byte either way.
        func alpha(_ x: Int, _ y: Int) -> UInt8 { base[y * rowBytes + x * 4 + 3] }

        // The radius from the transparent run along the diagonal (a quarter circle of radius r is cut away to a depth
        // of r * (1 - 1/sqrt 2) there).
        var radius = 0
        for t in 0..<min(width, height) / 2 where alpha(t, t) > 200 {
            radius = Int((Double(t) / 0.2929).rounded())
            break
        }
        guard radius > 0 else { return (image, 0) }

        let r = min(radius, width / 2, height / 2)
        func extend(row y: Int, from: Int, to: Int, step: Int) {
            var x = from
            while x != to, alpha(x, y) < 250 { x += step }
            guard x != to, x != from else { return }
            let source = y * rowBytes + x * 4
            var p = from
            while p != x {
                let at = y * rowBytes + p * 4
                for c in 0..<4 { base[at + c] = base[source + c] }
                p += step
            }
        }
        for y in Array(0..<r) + Array((height - r)..<height) {
            extend(row: y, from: 0, to: r, step: 1)
            extend(row: y, from: width - 1, to: width - 1 - r, step: -1)
        }
        return (context.makeImage() ?? image, radius)
    }

    /// The alpha of the picture's top left pixel.
    private static func cornerAlpha(of image: CGImage) -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        return pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return 255 }
            context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
            return bytes[3]
        }
    }
}
