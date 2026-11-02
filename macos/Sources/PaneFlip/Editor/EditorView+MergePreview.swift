import AppKit
import PaneFlipCore
import SwiftUI

extension EditorView {
    struct MergePreview {
        let source: ZoneRect
        let target: ZoneRect?
        let result: StripLayout?
        var valid: Bool { result != nil }
    }
}
