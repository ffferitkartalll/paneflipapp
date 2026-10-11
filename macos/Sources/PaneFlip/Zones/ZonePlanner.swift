import CoreGraphics
import Foundation
import PaneFlipCore

/// Works out which zones are on screen right now and where. Pure calculation over the layouts and settings.
struct ZonePlanner {
    let layouts: LayoutRepository
    let settings: AppSettings

    func visibleZones(on screens: [ScreenInfo]) -> [UUID: CGRect] {
        guard settings.values.placementEnabled else { return [:] }
        var zones: [UUID: CGRect] = [:]
        for screen in screens {
            guard let layout = layouts.activeLayout(for: screen.key) else { continue }
            for zone in layout.root.zones(in: screen.axVisible, gap: CGFloat(settings.values.gap)) { zones[zone.id] = zone.rect }
        }
        return zones
    }
}
