import CoreGraphics
import Foundation
import PaneFlipCore

/// The scenes at work: choosing one puts its layouts on the displays; when a display is unplugged the windows of its zones go where the scene in use says,
/// and when it is plugged in again they go back (the slots remember the zones they left, see `StackMemory.remap`).
final class SceneService: SceneManaging, SceneDisplacing {
    private let scenes: SceneRepository
    private let repository: LayoutRepository
    private let layouts: LayoutManaging
    private let memory: StackMemory
    private let coordinator: StackCoordinator
    private let screens: ScreenProviding
    private let arrangement: () -> DeskArrangement
    /// Every display seen since the app started: what an unplugged display looked like is no longer to be asked of the system.
    private var known: [String: ScreenInfo] = [:]

    init(scenes: SceneRepository, repository: LayoutRepository, layouts: LayoutManaging, memory: StackMemory, coordinator: StackCoordinator, screens: ScreenProviding,
         arrangement: @escaping () -> DeskArrangement) {
        self.scenes = scenes
        self.repository = repository
        self.layouts = layouts
        self.memory = memory
        self.coordinator = coordinator
        self.screens = screens
        self.arrangement = arrangement
    }

    // MARK: SceneManaging

    func select(id: UUID) {
        scenes.select(id)
        guard let scene = scenes.scenes.first(where: { $0.id == id }) else { return }
        apply(scene, toDisplay: nil)
    }

    /// Puts the layouts of a scene on the displays (on one of them when `display` is given).
    private func apply(_ scene: DisplayScene, toDisplay display: String?) {
        for screen in screens.screens() where screen.desktopNumber != nil && (display == nil || screen.displayID == display) {
            let wanted = scene.layouts[screen.displayID] ?? repository.layouts(for: screen.key).first?.id
            if let wanted, repository.activeLayout(for: screen.key)?.id != wanted, !repository.isTaken(layout: wanted, key: screen.key) {
                layouts.activate(key: screen.key, id: wanted)
            }
        }
    }

    @discardableResult func addScene() -> DisplayScene { scenes.add() }
    func rename(id: UUID, to name: String) { scenes.rename(id, to: name) }
    func remove(id: UUID) { scenes.remove(id) }
    func reset(id: UUID) { scenes.reset(id) }
    /// A layout chosen for a display in the scene in use is put on it at once.
    func setLayout(sceneID: UUID, display: String, layoutID: UUID) {
        scenes.setLayout(layoutID, ofDisplay: display, inScene: sceneID)
        if scenes.activeScene.id == sceneID { apply(scenes.activeScene, toDisplay: display) }
    }
    func setMoves(sceneID: UUID, zone: UUID, to destinations: [UUID]) { scenes.setMoves(ofZone: zone, to: destinations, inScene: sceneID) }

    // MARK: SceneDisplacing

    func displaysDidChange(on current: [ScreenInfo]) {
        for screen in current { known[screen.displayID] = screen }
        let connected = Set(current.map(\.displayID))
        let before = scenes.seenDisplays
        guard connected != before else { return }
        scenes.seenDisplays = connected
        guard !before.isEmpty else { return }   // the first look: nothing was plugged in or out
        bringBack(to: current.filter { connected.subtracting(before).contains($0.displayID) })
        displace(from: Set(repository.displayIDs).subtracting(connected), onto: current)
    }

    /// The windows of the zones of unplugged displays go where the scene in use says, else where they lie nearest on the desk (`SceneMoves.onDesk`).
    private func displace(from gone: Set<String>, onto current: [ScreenInfo]) {
        let remaining = DeskSpace.distinct(current.filter { $0.desktopNumber != nil })
        let targets = remaining.compactMap { screen in repository.activeLayout(for: screen.key).map { (screen: screen, layout: $0) } }
        guard !gone.isEmpty, let first = targets.first else { return }
        // Where the displays stand on the desk: the unplugged ones as they last were (their size as seen, else as large as a remaining one).
        let missing = gone.sorted()
        let sizes = targets.map { (id: $0.screen.displayID, size: $0.screen.deskSize) } + missing.map { (id: $0, size: known[$0]?.deskSize ?? first.screen.deskSize) }
        let frames = arrangement().frames(of: sizes)
        let desk = targets.map { (frame: frames[$0.screen.displayID] ?? .zero, layout: $0.layout) }
        let shown = Set(targets.flatMap { $0.layout.strip.zoneIDs })
        let moves = scenes.activeScene.moves
        var map: [UUID: UUID] = [:]
        for display in missing {
            for layout in repository.layouts(ofDisplay: display) {
                let placed = SceneMoves.onDesk(from: (frames[display] ?? .zero, layout), onto: desk).zones
                for (zone, place) in placed { map[zone] = moves[zone]?.first { shown.contains($0) } ?? place.zone }
            }
        }
        // Their windows stand in the target zones in the order of the zones they came from.
        let order = missing.flatMap { display in repository.layouts(ofDisplay: display).flatMap { $0.strip.zoneIDs } }
        release(memory.remap(map, sourceOrder: order))
    }

    /// The windows that left the zones of the plugged-in displays go back to them.
    private func bringBack(to plugged: [ScreenInfo]) {
        let preferred = Set(plugged.flatMap { repository.activeLayout(for: $0.key)?.strip.zoneIDs ?? [] })
        guard !preferred.isEmpty else { return }
        let map = Dictionary(memory.records.map { ($0.zoneID, $0.zoneID) }, uniquingKeysWith: { first, _ in first })
        release(memory.remap(map, preferred: preferred))
    }

    private func release(_ windowIDs: [CGWindowID]) {
        windowIDs.forEach { coordinator.removeFromStack(window: $0) }
    }
}
