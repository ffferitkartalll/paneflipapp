import Foundation

/// The standard shortcuts of the app: with Caps Lock as a modifier key they are built on it, without it on Control and Option.
public enum StandardShortcuts {
    public typealias Path = WritableKeyPath<SettingsValues, SnapTrigger>

    public static func values(capsLock: Bool) -> [Path: SnapTrigger] {
        guard capsLock else {
            return [\.snapTrigger: .windowSnap, \.nextWindowShortcut: .nextWindow, \.previousWindowShortcut: .previousWindow,
                    \.enlargeWindowShortcut: .enlargeWindow, \.windowScrollKeys: .windowScroll, \.sendToZoneKeys: .sendToZone,
                    \.undoWindowShortcut: .undoWindow, \.closeWindowUndoNoticeShortcut: .closeWindowUndoNotice,
                    \.zoneUpShortcut: .zoneUp, \.zoneLeftShortcut: .zoneLeft, \.zoneDownShortcut: .zoneDown, \.zoneRightShortcut: .zoneRight,
                    \.scrollRightShortcut: .scrollRight, \.scrollLeftShortcut: .scrollLeft, \.stripScrollKeys: .stripScroll, \.zoneEdgeEditKeys: .zoneEdgeEdit]
        }
        // Caps Lock first, then the keys in key-code order, as the recorder makes them.
        let caps = SnapTrigger.Key(code: KeyChord.capsLockKeyCode, name: "Caps Lock"), shift = SnapTrigger.Key(code: 56, name: "Left Shift")
        func with(_ keys: SnapTrigger.Key...) -> SnapTrigger { SnapTrigger(keys: [caps] + keys) }
        let right = SnapTrigger.Key(code: 124, name: "→"), left = SnapTrigger.Key(code: 123, name: "←")
        return [\.snapTrigger: with(), \.nextWindowShortcut: with(right), \.previousWindowShortcut: with(left),
                \.enlargeWindowShortcut: with(.init(code: 36, name: "Return")), \.windowScrollKeys: with(), \.sendToZoneKeys: with(.init(code: 46, name: "M")),
                \.undoWindowShortcut: with(.init(code: 51, name: "Delete")), \.closeWindowUndoNoticeShortcut: with(.init(code: 53, name: "Escape")),
                \.zoneUpShortcut: with(.init(code: 34, name: "I")), \.zoneLeftShortcut: with(.init(code: 38, name: "J")),
                \.zoneDownShortcut: with(.init(code: 40, name: "K")), \.zoneRightShortcut: with(.init(code: 37, name: "L")),
                \.scrollRightShortcut: with(shift, right), \.scrollLeftShortcut: with(shift, left), \.stripScrollKeys: with(shift), \.zoneEdgeEditKeys: with()]
    }
}
