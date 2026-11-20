import SwiftUI

extension NSAppearance {
    /// The dark appearance (also the vibrant dark one).
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

extension NSColor {
    /// `light` in the light appearance, `dark` in the dark one: asked when it is drawn, so it follows the system's change at once.
    convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { $0.isDark ? dark : light }
    }

    /// The colour as it is in the light or the dark appearance, in sRGB (for what is mixed with other colours).
    func rgb(dark: Bool) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var found = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0))
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            if let c = usingColorSpace(.sRGB) { found = (c.redComponent, c.greenComponent, c.blueComponent) }
        }
        return found
    }

    /// White in the dark appearance, black in the light one: what is drawn on the ground of the appearance.
    static let contrast = NSColor(light: .black, dark: .white)
}

extension Color {
    static let contrast = Color(nsColor: .contrast)
    /// The ground of a canvas: black in the dark appearance (as it was), the window's own in the light one.
    static let canvas = Color(nsColor: NSColor(light: .windowBackgroundColor, dark: .black))   // built from the colours themselves: a Color made of a dynamic colour is fixed when it is converted
    /// `light` in the light appearance, `dark` in the dark one.
    init(light: Color, dark: Color) { self.init(nsColor: NSColor(light: NSColor(light), dark: NSColor(dark))) }
}
