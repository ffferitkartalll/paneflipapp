import AppKit
import SwiftUI

extension FullWidthSegments {
    final class Coordinator: NSObject {
        var parent: FullWidthSegments
        init(_ parent: FullWidthSegments) { self.parent = parent }

        @objc func changed(_ sender: NSSegmentedControl) {
            guard parent.options.indices.contains(sender.selectedSegment) else { return }
            parent.selection = parent.options[sender.selectedSegment].value
        }
    }
}
