import CoreGraphics
import Foundation
import Observation

/// Owns every screen's layouts and persists them. Knows nothing about windows: it only stores layout data.
/// Screens are addressed by an opaque key ("displayUUID|desktopID").
@Observable
public final class LayoutRepository {
    public private(set) var screens: [String: ScreenLayouts] = [:] {
        didSet { store.save(screens, named: Self.documentName) }
    }
    @ObservationIgnored private let store: DocumentStore
    private static let documentName = "layouts-v2"

    public init(store: DocumentStore) {
        self.store = store
        if let loaded = store.load([String: ScreenLayouts].self, named: Self.documentName) { screens = Self.sharedByDisplay(loaded) }
    }

    /// Documents from before layouts were shared keep one entry per desktop ("display|d2"): the layouts of a display's
    /// desktops are gathered under the display, each desktop keeping the layout it had active.
    private static func sharedByDisplay(_ loaded: [String: ScreenLayouts]) -> [String: ScreenLayouts] {
        var result: [String: ScreenLayouts] = [:]
        for (key, entry) in loaded {
            let (display, desktop) = split(key)
            guard desktop.first == "d", Int(desktop.dropFirst()) != nil else { result[key] = result[key] ?? entry; continue }
            var shared = result[display] ?? ScreenLayouts()
            shared.layouts += entry.layouts.filter { new in !shared.layouts.contains { $0.id == new.id } }
            if let active = entry.legacyActive { shared.byDesktop[desktop] = active }
            result[display] = shared
        }
        return result
    }

    /// A screen key names a desktop of a display ("display|d2"). A display's layouts are shared by its desktops.
    public func layouts(for key: String) -> [NamedLayout] { screens[Self.split(key).display]?.layouts ?? [] }
    public func activeLayout(for key: String) -> NamedLayout? {
        let (display, desktop) = Self.split(key)
        guard let s = screens[display], let id = s.byDesktop[desktop] else { return nil }
        return s.layouts.first { $0.id == id }
    }
    public func layout(id: UUID, key: String) -> NamedLayout? { layouts(for: key).first { $0.id == id } }

    /// Whether another desktop of the key's display uses the layout. Two desktops never share one: they would share its
    /// zones, and with them the stacks of windows that live on only one of the desktops.
    public func isTaken(layout id: UUID, key: String) -> Bool {
        let (display, desktop) = Self.split(key)
        return screens[display]?.byDesktop.contains { $0.key != desktop && $0.value == id } ?? false
    }

    /// Every zone identifier of every layout (active or not).
    public var allZoneIDs: Set<UUID> {
        Set(screens.values.flatMap { $0.layouts.flatMap { $0.strip.zoneIDs } })
    }

    @discardableResult
    public func addLayout(for key: String, named name: String? = nil, preset: LayoutPreset = .single) -> NamedLayout {
        let (display, desktop) = Self.split(key)
        var s = screens[display] ?? ScreenLayouts()
        let layout = NamedLayout(name: name ?? "Layout \(s.layouts.count + 1)", root: preset.root)
        s.layouts.append(layout)
        if s.byDesktop[desktop] == nil { s.byDesktop[desktop] = layout.id }
        screens[display] = s
        return layout
    }

    /// Adds a copy of a layout to the display's layouts; no desktop uses it yet.
    @discardableResult
    public func duplicateLayout(id: UUID, key: String, named name: String) -> NamedLayout? {
        let display = Self.split(key).display
        guard var s = screens[display], let original = s.layouts.first(where: { $0.id == id }) else { return nil }
        let copy = original.copy(named: name)
        s.layouts.append(copy)
        screens[display] = s
        return copy
    }

    public func setStrip(_ strip: StripLayout, ofLayout id: UUID, key: String) {
        guard var s = screens[Self.split(key).display], let i = s.layouts.firstIndex(where: { $0.id == id }) else { return }
        s.layouts[i].strip = strip
        screens[Self.split(key).display] = s
    }

    public func rename(layout id: UUID, key: String, to name: String) {
        guard var s = screens[Self.split(key).display], let i = s.layouts.firstIndex(where: { $0.id == id }) else { return }
        s.layouts[i].name = name
        screens[Self.split(key).display] = s
    }

    public func setDefaultZone(_ zone: UUID?, ofLayout id: UUID, key: String) {
        guard var s = screens[Self.split(key).display], let i = s.layouts.firstIndex(where: { $0.id == id }) else { return }
        s.layouts[i].defaultZoneID = zone
        screens[Self.split(key).display] = s
    }

    /// Every zone of every layout kept for a display that is not among `displays` (display identifiers).
    public func zoneIDs(ofDisplaysNotIn displays: Set<String>) -> Set<UUID> {
        var zones: Set<UUID> = []
        for (key, layouts) in screens where !displays.contains(Self.display(of: key)) {
            layouts.layouts.forEach { zones.formUnion($0.strip.zoneIDs) }
        }
        return zones
    }

    /// The keys a display had before desktops were told apart by their position ("display|<space id>").
    public func legacyKeys(ofDisplay display: String) -> [String] {
        screens.filter { Self.display(of: $0.key) == display && !$0.value.layouts.isEmpty }.keys
            .filter { $0.split(separator: "|").last.map { Int($0) != nil } ?? false }
    }

    /// Keeps the layouts a display kept under an old key as those of the desktop of the new key.
    public func moveScreen(from old: String, to new: String) {
        let (display, desktop) = Self.split(new)
        guard old != new, var moved = screens[old], layouts(for: new).isEmpty else { return }
        moved.byDesktop[desktop] = moved.legacyActive
        moved.activeID = nil
        screens[display] = moved
        screens[old] = nil
    }

    private static func display(of key: String) -> String { split(key).display }

    private static func split(_ key: String) -> (display: String, desktop: String) {
        guard let bar = key.lastIndex(of: "|") else { return (key, "") }
        return (String(key[..<bar]), String(key[key.index(after: bar)...]))
    }

    /// Makes the layout the key's desktop uses; refused while another desktop of the display uses it.
    public func activate(layout id: UUID, key: String) {
        let (display, desktop) = Self.split(key)
        guard var s = screens[display], s.layouts.contains(where: { $0.id == id }), !isTaken(layout: id, key: key) else { return }
        s.byDesktop[desktop] = id
        screens[display] = s
    }

    /// Desktops of a display past its last one were removed: they stop holding a layout (and no longer keep it from the others).
    public func forgetDesktops(ofDisplay display: String, after count: Int) {
        guard var s = screens[display] else { return }
        let kept = s.byDesktop.filter { desktop, _ in desktop.first != "d" || Int(desktop.dropFirst()).map { $0 <= count } ?? true }
        guard kept != s.byDesktop else { return }
        s.byDesktop = kept
        screens[display] = s
    }

    /// The key's desktop uses no layout: it has no zones.
    public func deactivate(key: String) {
        let (display, desktop) = Self.split(key)
        guard var s = screens[display], s.byDesktop[desktop] != nil else { return }
        s.byDesktop[desktop] = nil
        screens[display] = s
    }

    public func removeLayout(id: UUID, key: String) {
        let display = Self.split(key).display
        guard var s = screens[display] else { return }
        s.layouts.removeAll { $0.id == id }
        s.byDesktop = s.byDesktop.filter { $0.value != id }
        screens[display] = s
    }
}
