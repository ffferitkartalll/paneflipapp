import Foundation
import PaneFlipCore

/// Records what the map of the strip was asked to show.
final class FakeScrollPreview: ScrollPreviewing {
    private(set) var offsets: [Double] = []
    private(set) var hides: [TimeInterval] = []

    func show(strip: StripLayout, offset: Double, on screen: ScreenInfo) { offsets.append(offset) }
    func hide(after delay: TimeInterval) { hides.append(delay) }
}
