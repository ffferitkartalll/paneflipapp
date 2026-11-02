import AppKit
import PaneFlipCore
import SwiftUI

/// The apps of one zone: each can be opened to show its windows. Apps and windows are reordered by their handles.
struct ZoneAppsList: View {
    let entries: [LayoutAppEntry]
    let zones: [UUID]
    let title: (UUID) -> Text
    let editor: LayoutAppsEditing
    let startApps: Set<String>
    let setStartApp: (String, Bool) -> Void

    static let appHeight: CGFloat = 44
    static let windowHeight: CGFloat = 34
    @State private var opened: Set<String> = []

    var body: some View {
        ReorderableStack(items: entries, height: height, space: "zoneApps") { from, to in
            editor.reorder(app: entries[from].bundleID, in: entries[from].zoneID, by: to - from, inZones: zones)
        } row: { entry, isCarried, drag, drop in
            LayoutAppRow(entry: entry, zones: zones, title: title, editor: editor, isChosen: binding(for: entry), isCarried: isCarried, isOpen: opened.contains(entry.id),
                         toggle: { toggle(entry.id) }, drag: drag, drop: drop)
                .frame(height: height(entry), alignment: .top)
                .overlay(alignment: .bottom) { if entry.id != entries.last?.id { Divider() } }
        }
    }

    private func binding(for entry: LayoutAppEntry) -> Binding<Bool> {
        Binding(get: { startApps.contains(entry.bundleID) }, set: { setStartApp(entry.bundleID, $0) })
    }

    private func height(_ entry: LayoutAppEntry) -> CGFloat {
        opened.contains(entry.id) && entry.windows.count > 1
            ? Self.appHeight + CGFloat(entry.windows.count) * Self.windowHeight + 6
            : Self.appHeight
    }

    private func toggle(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if opened.contains(id) { opened.remove(id) } else { opened.insert(id) }
        }
    }
}
