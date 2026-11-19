import CoreGraphics
import SwiftUI

extension ZoneWindowsModel {
    /// The dashed lines round `places`, drawn once as a picture and kept until the places change: a line that is drawn is painted again at every step of a slide, a picture is not.
    func outlinePicture(of places: [CGRect]) -> CGImage? {
        if let kept = outlines, kept.places == places, kept.size == size { return kept.picture }
        let size = self.size
        let picture = MainActor.assumeIsolated { () -> CGImage? in
            let renderer = ImageRenderer(content: CellOutlines(cells: places, lineWidth: 1.5)
                .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                .frame(width: size.width, height: size.height, alignment: .topLeading))
            renderer.scale = 2
            return renderer.cgImage
        }
        outlines = picture.map { (places, size, $0) }
        return picture
    }
}
