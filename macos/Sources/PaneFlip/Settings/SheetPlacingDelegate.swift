import AppKit

/// Stands in for the delegate of a window while a sheet (`under`) is attached to it, and puts a sheet that opens over that sheet `inset` lower. The system attaches a
/// sheet to its window under the toolbar, where the sheet under stands, and centres it on the window but never higher than that: a sheet `inset` lower and as much
/// smaller as twice the inset lies that far inside the sheet under it on every side. Everything else goes to the window's own delegate, which takes its place again
/// when the sheet under has gone.
final class SheetPlacingDelegate: NSObject, NSWindowDelegate {
    /// Held while standing in: the window's notifications were registered for it, and they come here (a window holds its delegate weakly, so this makes no cycle).
    private let original: NSWindowDelegate?
    private weak var under: NSWindow?
    private let inset: CGFloat
    /// Itself while it stands in: a window holds its delegate weakly.
    private var standing: SheetPlacingDelegate?

    private init(original: NSWindowDelegate?, under: NSWindow, inset: CGFloat) {
        self.original = original
        self.under = under
        self.inset = inset
    }

    /// Puts the sheets that open over `sheet`, the sheet attached to `window`, `inset` inside it until it has gone.
    static func install(on window: NSWindow, under sheet: NSWindow, inset: CGFloat) {
        guard window.attachedSheet === sheet else { return }
        if let standing = window.delegate as? SheetPlacingDelegate {   // one that stayed: it takes this sheet
            standing.under = sheet
            return
        }
        let delegate = SheetPlacingDelegate(original: window.delegate, under: sheet, inset: inset)
        delegate.standing = delegate
        window.delegate = delegate
    }

    // MARK: Everything else to the window's own delegate

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original?.responds(to: aSelector) == true ? original : nil
    }

    // MARK: NSWindowDelegate

    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
        let place = original?.window?(window, willPositionSheet: sheet, using: rect) ?? rect
        guard let under, window.attachedSheet === under, sheet !== under else { return place }
        return place.offsetBy(dx: 0, dy: -inset)
    }

    func windowDidEndSheet(_ notification: Notification) {
        original?.windowDidEndSheet?(notification)
        guard let window = notification.object as? NSWindow, under == nil || window.attachedSheet !== under else { return }
        if window.delegate === self { window.delegate = original }
        standing = nil
    }
}
