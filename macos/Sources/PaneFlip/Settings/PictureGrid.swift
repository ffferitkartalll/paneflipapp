import CoreGraphics

/// How many columns a grid of pictures has and how wide each picture is, so that the pictures fill the width of the grid: as many columns as fit at the
/// wanted width, one more when the room left over is a tenth of a picture or more; the pictures then grow or shrink to fill it exactly.
struct PictureGrid {
    let columns: Int
    let picture: CGFloat

    init(width: CGFloat, wanted: CGFloat, spacing: CGFloat) {
        let fit = max(Int((width + spacing) / (wanted + spacing)), 1)
        let left = width - (CGFloat(fit) * wanted + CGFloat(fit - 1) * spacing)
        columns = left >= wanted / 10 ? fit + 1 : fit
        picture = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    }
}
