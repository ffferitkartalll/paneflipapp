import AppKit

extension NestedSheetPlacement {
    /// In the sheet: once the sheet is attached to its window, that window puts the sheets over it `inset` lower.
    final class Anchor: NSView {
        var inset: CGFloat = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // The content is put in the sheet before the sheet is attached to its window.
            // shortcut: one turn of the main queue was always enough (macOS 27); if a later system attached sheets later, look again a little after.
            DispatchQueue.main.async { [weak self] in
                guard let self, let sheet = self.window, let window = sheet.sheetParent else { return }
                SheetPlacingDelegate.install(on: window, under: sheet, inset: self.inset)
            }
        }
    }
}
