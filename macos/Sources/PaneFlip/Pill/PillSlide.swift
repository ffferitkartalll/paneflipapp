import AppKit

/// Draws the segments of the pill sliding from their old places to their new ones when the order changes. The
/// system control has no animation of its own for changed titles, so while this runs the real segments hold blank
/// space and these labels, drawn like the real ones, move over them.
final class PillSlide {
    struct Item {
        let name: String
        let icon: NSImage?
        let from: NSRect
        let to: NSRect
    }

    private var views: [NSView] = []
    private var completion: (() -> Void)?

    var isRunning: Bool { !views.isEmpty }

    func run(_ items: [Item], showsIcon: Bool, showsName: Bool, in parent: NSView, duration: TimeInterval,
             completion: @escaping () -> Void) {
        finish()
        self.completion = completion
        let font = NSFont.systemFont(ofSize: 13)
        let icon: CGFloat = 18, gap: CGFloat = 5
        for item in items {
            let container = NSView(frame: item.from)
            let text = NSString(string: item.name)
            let textWidth = showsName ? ceil(text.size(withAttributes: [.font: font]).width) : 0
            let content = (showsIcon ? icon : 0) + (showsIcon && showsName ? gap : 0) + textWidth
            var x = ((item.from.width - content) / 2).rounded()
            if showsIcon {
                let image = NSImageView(frame: NSRect(x: x, y: (item.from.height - icon) / 2, width: icon, height: icon))
                image.image = item.icon
                image.imageScaling = .scaleProportionallyUpOrDown
                container.addSubview(image)
                x += icon + gap
            }
            if showsName {
                let label = NSTextField(labelWithString: item.name)
                label.font = font
                label.textColor = .white
                label.sizeToFit()
                label.frame.origin = NSPoint(x: x, y: ((item.from.height - label.frame.height) / 2).rounded())
                container.addSubview(label)
            }
            parent.addSubview(container)
            views.append(container)
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (view, item) in zip(views, items) { view.animator().frame = item.to }
        }, completionHandler: { [weak self] in self?.finish() })
    }

    /// Ends a running slide at once.
    func finish() {
        views.forEach { $0.removeFromSuperview() }
        views = []
        let done = completion
        completion = nil
        done?()
    }
}
