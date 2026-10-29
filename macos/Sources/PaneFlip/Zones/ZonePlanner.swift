import CoreGraphics
import Foundation
import PaneFlipCore

/// Works out which zones exist right now and where, for the scroll each screen is at. Pure calculation over the layouts,
/// the settings and the scroll.
struct ZonePlanner {
    let layouts: LayoutRepository
    let settings: AppSettings
    let viewport: StripViewport

    /// Zones in view stand where they are; zones scrolled out of sight wait at a display's edge (see `Parking`). A screen
    /// with a display on each side has no such place, so the zones beyond its edges do not exist there.
    func plan(on screens: [ScreenInfo]) -> [UUID: PlannedZone] {
        guard settings.values.placementEnabled else { return [:] }
        var zones: [UUID: PlannedZone] = [:]
        for screen in screens {
            guard let (geometry, side) = strip(of: screen, among: screens) else { continue }
            let layout = layouts.activeLayout(for: screen.key)
            let offset = geometry.clamped(viewport.offset(for: screen.key))
            for zone in geometry.zones(offset: offset, gap: CGFloat(layouts.activeLayout(for: screen.key)?.gap ?? settings.values.gap),
                                         margin: CGFloat(settings.values.edgeMargin)) {
                let number = layout?.strip.position(of: zone.id)?.number ?? 0
                let order = layout?.strip.zoneIDs.firstIndex(of: zone.id) ?? 0
                if zone.isOnScreen {
                    zones[zone.id] = PlannedZone(rect: zone.rect, number: number, order: order)
                } else if let side {
                    zones[zone.id] = PlannedZone(rect: zone.rect, frame: Parking.frame(for: zone.rect, on: screen.cocoaFrame, side: side), isParked: true, number: number, order: order)
                }
            }
        }
        return zones
    }

    /// Where a zone will stand on `screen` once the layout has scrolled to `offset`: the same rectangle `plan` gives then.
    func rect(of zone: UUID, at offset: CGFloat, on screen: ScreenInfo, among screens: [ScreenInfo]) -> CGRect? {
        guard let (geometry, _) = strip(of: screen, among: screens) else { return nil }
        return geometry.zones(offset: offset, gap: CGFloat(layouts.activeLayout(for: screen.key)?.gap ?? settings.values.gap),
                              margin: CGFloat(settings.values.edgeMargin)).first { $0.id == zone }?.rect
    }

    /// The strip of a screen's active layout and the side its out-of-sight windows wait at (nil: nowhere, so the areas
    /// beyond its edges are left out).
    func strip(of screen: ScreenInfo, among screens: [ScreenInfo]) -> (StripGeometry, Parking.Side?)? {
        guard let layout = layouts.activeLayout(for: screen.key) else { return nil }
        let others = screens.filter { $0.displayID != screen.displayID }.map(\.cocoaFrame)
        let side = Parking.side(of: screen.cocoaFrame, others: others)
        return (StripGeometry(strip: side == nil || !settings.values.overflowZonesEnabled ? StripLayout(root: layout.root) : layout.strip,
                                       screen: screen.axVisible), side)
    }
}
