import AppKit
import SwiftUI

/// Put in a sheet: a sheet that opens over it lies `inset` lower, inside it (see `SheetPlacingDelegate`); one as much smaller as twice the inset lies that far inside it
/// on every side.
struct NestedSheetPlacement: NSViewRepresentable {
    let inset: CGFloat

    func makeNSView(context: Context) -> Anchor { Anchor() }

    func updateNSView(_ view: Anchor, context: Context) { view.inset = inset }
}
