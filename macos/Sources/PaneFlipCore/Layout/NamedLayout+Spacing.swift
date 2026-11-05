import Foundation

extension NamedLayout {
    /// The gap between its zones, the margin round its screens and the least a zone may be, in points: those the user set for this layout in the layout editor,
    /// or the ones of the settings for a layout that has none.
    public func gap(in settings: SettingsValues) -> Double { gap ?? settings.gap }
    public func edgeMargin(in settings: SettingsValues) -> Double { edgeMargin ?? settings.edgeMargin }
    public func minZoneSize(in settings: SettingsValues) -> Double { minZoneSize ?? settings.minZoneSize }
}
