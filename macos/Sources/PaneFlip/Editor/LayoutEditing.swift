import Foundation

/// What the rest of the app may ask of the layout editor.
protocol LayoutEditing: AnyObject {
    var isShown: Bool { get }
    /// Edits (or closes the editor of) the active layout of the screen under the pointer, creating a layout if the screen has none.
    func toggleAtPointer()
    func edit(on screen: ScreenInfo, layoutID: UUID)
}
