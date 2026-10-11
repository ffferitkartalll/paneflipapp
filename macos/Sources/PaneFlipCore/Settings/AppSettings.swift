import Foundation
import Observation

/// User settings. Observable for the UI; changes persist immediately and the two feature switches notify listeners.
@Observable
public final class AppSettings {
    /// Gap between zones: 0–80 pt in steps of 4.
    public static let gapRange = 0.0...80.0
    public static let gapStep = 4.0
    /// Smallest zone: 240–320 pt in steps of 4.
    public static let minZoneSizeRange = 240.0...320.0
    public static let minZoneSizeStep = 4.0

    /// Master switch: place apps into zones at all (snapping, remembering, restoring, the pill).
    public var placementEnabled: Bool {
        didSet { if placementEnabled != oldValue { persist(); onPlacementChanged?() } }
    }
    /// Several apps per zone, switched with the pill. When off, a zone holds one app and a new one replaces it.
    public var stackingEnabled: Bool {
        didSet { if stackingEnabled != oldValue { persist(); onStackingChanged?() } }
    }
    /// Space between zones in points; not applied to screen edges.
    public var gap: Double { didSet { persist() } }
    /// Smallest width/height a zone may have, in points.
    public var minZoneSize: Double { didSet { persist() } }
    /// What the stack pill shows for each window.
    public var pillContent: PillContent { didSet { persist() } }
    /// Held while dragging a window to highlight zones and snap into one.
    public var snapTrigger: SnapTrigger { didSet { persist() } }

    @ObservationIgnored public var onPlacementChanged: (() -> Void)?
    @ObservationIgnored public var onStackingChanged: (() -> Void)?
    @ObservationIgnored private let storage: SettingsStorage

    public init(storage: SettingsStorage) {
        self.storage = storage
        let v = storage.load()
        placementEnabled = v.placementEnabled
        stackingEnabled = v.stackingEnabled
        gap = Self.snapped(v.gap, to: Self.gapRange, step: Self.gapStep)
        minZoneSize = Self.snapped(v.minZoneSize, to: Self.minZoneSizeRange, step: Self.minZoneSizeStep)
        pillContent = v.pillContent
        snapTrigger = v.snapTrigger
    }

    /// Brings a stored value (possibly from an older version with other limits) onto the allowed grid.
    static func snapped(_ value: Double, to range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let steps = ((clamped - range.lowerBound) / step).rounded()
        return min(range.lowerBound + steps * step, range.upperBound)
    }

    private func persist() {
        var v = SettingsValues()
        v.placementEnabled = placementEnabled
        v.stackingEnabled = stackingEnabled
        v.gap = gap
        v.minZoneSize = minZoneSize
        v.pillContent = pillContent
        v.snapTrigger = snapTrigger
        storage.save(v)
    }
}
