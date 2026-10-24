import AppKit
import QuartzCore

/// A window's picture as a layer: the picture with the window's rounded corners, and the shadow a window has under and around it. Wherever
/// pictures stand in for windows they look like windows.
final class WindowPictureLayer: CALayer {
    private let body = CALayer()
    private let radius: CGFloat

    init(_ picture: WindowPicture) {
        radius = picture.cornerRadius
        super.init()
        body.contents = picture.image
        body.contentsGravity = .resize
        body.cornerRadius = radius
        body.cornerCurve = .continuous
        body.masksToBounds = true
        // The shadow every window of macOS has, as the window server tells it for a window (`CGSGetWindowShadowAndRimParameters`): a Gaussian
        // with a standard deviation of 32.94, a density of 0.7, lowered by 18 points.
        shadowColor = NSColor.black.cgColor
        shadowOpacity = 0.7
        shadowRadius = 32.94
        shadowOffset = CGSize(width: 0, height: -18)
        addSublayer(body)
    }

    override init(layer: Any) {
        let other = layer as? WindowPictureLayer
        radius = other?.radius ?? 0
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("not made from a file") }

    /// A newer photograph of the same window.
    func update(_ image: CGImage) { body.contents = image }

    override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body.frame = bounds
        // The shadow follows the rounded shape, not the transparent rectangle of the layer.
        shadowPath = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        CATransaction.commit()
    }
}
