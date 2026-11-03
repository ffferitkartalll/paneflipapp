import Foundation

/// Lights the zones of every screen while a window is on its way to one of them.
protocol ZoneLighting: AnyObject {
    var isShown: Bool { get }
    func show(zones: [(id: UUID, rect: CGRect)])
    func highlight(zone id: UUID?)
    func hide()
}
