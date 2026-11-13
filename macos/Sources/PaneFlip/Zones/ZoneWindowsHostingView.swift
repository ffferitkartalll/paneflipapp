import AppKit
import SwiftUI

/// The grid of a zone's windows lies in a panel the app does not activate: the first click on it is to be a click on a card, not only the one that gives the panel the focus.
final class ZoneWindowsHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
