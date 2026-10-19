import Foundation
import Observation

/// User settings. Observable for the UI. All of them live in one `SettingsValues`; changing it saves it, and the
/// feature switches notify their listeners.
@Observable
public final class AppSettings {
    /// Gap between zones: 0–80 pt in steps of 4.
    public static let gapRange = 0.0...80.0
    public static let gapStep = 4.0
    /// Smallest zone: 240–320 pt in steps of 4.
    public static let minZoneSizeRange = 240.0...320.0
    public static let minZoneSizeStep = 4.0

    public var values: SettingsValues {
        didSet {
            guard values != oldValue else { return }
            storage.save(values)
            if values.placementEnabled != oldValue.placementEnabled { onPlacementChanged?() }
            if values.stackingEnabled != oldValue.stackingEnabled { onStackingChanged?() }
            if values.overflowZonesEnabled != oldValue.overflowZonesEnabled { onOverflowZonesChanged?() }
        }
    }

    /// The language the app started with: a different choice only takes effect after a restart.
    @ObservationIgnored public let launchLanguage: String
    @ObservationIgnored public var onPlacementChanged: (() -> Void)?
    @ObservationIgnored public var onStackingChanged: (() -> Void)?
    @ObservationIgnored public var onOverflowZonesChanged: (() -> Void)?
    @ObservationIgnored private let storage: SettingsStorage

    public init(storage: SettingsStorage) {
        self.storage = storage
        var loaded = storage.load()
        loaded.gap = Self.snapped(loaded.gap, to: Self.gapRange, step: Self.gapStep)
        loaded.minZoneSize = Self.snapped(loaded.minZoneSize, to: Self.minZoneSizeRange, step: Self.minZoneSizeStep)
        launchLanguage = loaded.language
        values = loaded
    }

    /// Brings a stored value (possibly from an older version with other limits) onto the allowed grid.
    static func snapped(_ value: Double, to range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let steps = ((clamped - range.lowerBound) / step).rounded()
        return min(range.lowerBound + steps * step, range.upperBound)
    }
}
