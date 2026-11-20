import CoreGraphics
import SwiftUI

extension ZoneWindowsModel {
    /// The dashed lines round `places`, drawn once as a picture and kept until the places change: a line that is drawn is painted again at every step of a slide, a picture is not.
    func outlinePicture(of places: [CGRect]) -> CGImage? {
        let dark = NSApp.effectiveAppearance.isDark   // the picture is drawn in the colour of the appearance it was made in, and made again when that changes
        if let kept = outlines, kept.places == places, kept.size == size, kept.dark == dark { return kept.picture }
        let size = self.size
        let picture = MainActor.assumeIsolated { () -> CGImage? in
            let renderer = ImageRenderer(content: CellOutlines(cells: places, lineWidth: 1.5)
                .stroke((dark ? Color.white : Color.black).opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .frame(width: size.width, height: size.height, alignment: .topLeading))
            renderer.scale = 2
            return renderer.cgImage
        }
        outlines = picture.map { (places, size, dark, $0) }
        return picture
    }
}
