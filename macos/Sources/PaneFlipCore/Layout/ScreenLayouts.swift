import Foundation

/// The layouts of one screen (on one desktop) and which of them is active.
public struct ScreenLayouts: Codable, Equatable {
    public var layouts: [NamedLayout]
    public var activeID: UUID?

    public init(layouts: [NamedLayout] = [], activeID: UUID? = nil) {
        self.layouts = layouts
        self.activeID = activeID
    }

    public var active: NamedLayout? { layouts.first { $0.id == activeID } ?? layouts.first }
}
