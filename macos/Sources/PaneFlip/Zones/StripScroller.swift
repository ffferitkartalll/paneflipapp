import CoreGraphics
import Foundation
import PaneFlipCore

/// Scrolls the layout of the screen under the pointer, from the shortcut or the pointer resting at the screen's edge. Pictures of the
/// windows glide, moved by the render server (so they glide whatever the apps or the machine are doing); the real windows wait at
/// the display's edge meanwhile. Then the pictures glide on to the nearest rest position, the real windows
/// are put where they belong, and the pictures give way to them.
final class StripScroller {
    /// How long the pictures glide on to the rest position.
    private static let glide: TimeInterval = 0.3
    /// Pictures that have not come after this long are given up on: the windows then move at the end, without pictures.
    private static let giveUpAfter: TimeInterval = 1.5
    /// Pictures from an earlier scroll stand in for new ones this long, so the glide can begin at once.
    private static let keepPicturesFor: TimeInterval = 120
    /// A photograph this young is not taken again.
    private static let freshFor: TimeInterval = 10
    /// A frame or two for the windows to be drawn where they now stand, before the pictures go.
    private static let drawTime: TimeInterval = 0.05

    private enum Phase { case waiting, covering, gliding, landing }

    /// A window of the screen's zones, with where its zone stood when the scroll began.
    private struct Held {
        let ref: WindowRef
        let zone: UUID
        let rect: CGRect
        let isFront: Bool
        let isParked: Bool
    }

    private struct Scrolling {
        let id: Int
        let screen: ScreenInfo
        let geometry: StripGeometry
        let side: Parking.Side
        let start: CGFloat
        let held: [Held]
        /// The rest position the scroll is heading to.
        var target: CGFloat
        var pictures: [CGWindowID: WindowPicture] = [:]
        /// The photographs of this scroll have come (some window may be missing from them).
        var photographed = false
        var phase = Phase.waiting
        /// Where the pictures are now, between the start and the target.
        var shown: CGFloat
        var glideFrom: CGFloat = 0
        var glideTo: CGFloat = 0
        var glideBegan: TimeInterval = 0
        /// Two fingers lead this scroll: the pictures follow `gesture` until the fingers lift (`released`), then glide on to a rest position.
        var led = false
        var released = false
        var gesture = ScrubGesture()
    }

    /// Calls `tick` on every frame until it returns false.
    typealias Metronome = (_ tick: @escaping () -> Bool) -> Void

    private let screens: ScreenProviding
    private let planner: ZonePlanner
    private let viewport: StripViewport
    private let settings: AppSettings
    private let coordinator: StackCoordinator
    private let mover: WindowMover
    private let snapshots: WindowSnapshotting
    private let stage: ScrollStaging
    private let metronome: Metronome
    private let now: () -> TimeInterval
    private weak var refresher: ZoneRefreshing?
    private let reduceMotion: () -> Bool
    private let isBusy: () -> Bool
    private var scrolling: Scrolling?
    /// Called when a scroll is over and the windows are in their places.
    var onRest: (() -> Void)?
    /// The zone a focus change asked the scroll to bring into view; each scroll that comes to rest goes on until it shows.
    private var revealing: UUID?
    private var ticking = false
    private var count = 0
    private var isRunning = false
    /// The latest photograph of each window, with when it was taken.
    private var kept: [CGWindowID: (picture: WindowPicture, at: TimeInterval)] = [:]

    /// `isBusy`: something else holds the windows (Stage Manager, Mission Control): no scrolling then.
    init(screens: ScreenProviding, planner: ZonePlanner, viewport: StripViewport,
         settings: AppSettings, coordinator: StackCoordinator, mover: WindowMover, snapshots: WindowSnapshotting,
         stage: ScrollStaging, metronome: @escaping Metronome, refresher: ZoneRefreshing,
         reduceMotion: @escaping () -> Bool, isBusy: @escaping () -> Bool,
         now: @escaping () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }) {
        self.screens = screens
        self.planner = planner
        self.viewport = viewport
        self.settings = settings
        self.coordinator = coordinator
        self.mover = mover
        self.snapshots = snapshots
        self.stage = stage
        self.metronome = metronome
        self.refresher = refresher
        self.reduceMotion = reduceMotion
        self.isBusy = isBusy
        self.now = now
    }

    /// The app is up.
    func start() {
        isRunning = true
        // After the windows have settled in their zones.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.warm() }
    }

    /// The zones beyond the screens' edges were switched on or off.
    func settingDidChange() { warm() }

    /// Photographs the windows in front in every zone of the screens that can scroll, so the first scroll already has
    /// pictures to show.
    func warm() {
        guard isRunning, settings.values.overflowZonesEnabled, settings.values.placementEnabled, !isBusy(), !reduceMotion() else { return }
        let all = screens.screens()
        for screen in all {
            guard let (geometry, side) = planner.strip(of: screen, among: all), side != nil,
                  geometry.range.lowerBound < geometry.range.upperBound else { continue }
            // A picture taken a moment ago is as good: going back and forth does not photograph the windows at every stop.
            let fronts = held(of: geometry, at: geometry.clamped(viewport.offset(for: screen.key))).filter(\.isFront)
                .filter { front in kept[front.ref.id].map { now() - $0.at >= Self.freshFor } ?? true }
            guard !fronts.isEmpty else { continue }
            snapshots.snapshots(of: fronts.map(\.ref)) { [weak self] images in
                guard let self else { return }
                let at = now()
                for (id, picture) in images { kept[id] = (picture, at) }
                self.forgetOldPictures(at: at)
            }
        }
    }

    // MARK: Scrolling

    /// The shortcut: scrolls the screen under the pointer.
    @discardableResult
    func scroll(toward edge: ScreenEdge) -> Bool {
        let all = screens.screens()
        guard let screen = all.first(where: { $0.cocoaFrame.contains(screens.pointerCocoa) }) ?? all.first else { return false }
        return scroll(toward: edge, on: screen)
    }

    /// Brings the next rest position beyond `edge` of `screen` into view: the pictures glide, the windows land. A scroll that
    /// runs goes on to the next one the same way, or turns back when asked the other way. False when there is nothing more that
    /// way, or the windows are not free to be moved.
    @discardableResult
    func scroll(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        revealing = nil   // the user's own scroll wins over one a focus change asked for
        return scroll(toward: edge, on: screen, to: nil)
    }

    /// The scroll itself; `wanted` is the rest position to go to (the next one toward `edge` when there is none). `led`: the fingers lead
    /// it, from where the layout is now.
    private func scroll(toward edge: ScreenEdge, on screen: ScreenInfo, to wanted: CGFloat?, led: Bool = false) -> Bool {
        guard settings.values.placementEnabled, !isBusy() else { return false }
        if scrolling != nil { return carryOn(toward: edge, on: screen) }
        let all = screens.screens()
        guard let (geometry, found) = planner.strip(of: screen, among: all), let side = found else { return false }
        let offset = geometry.clamped(viewport.offset(for: screen.key))
        guard let target = led ? offset : wanted ?? nextRest(from: offset, toward: edge, in: geometry) else { return false }
        count += 1
        var current = Scrolling(id: count, screen: screen, geometry: geometry, side: side, start: offset,
                                held: held(of: geometry, at: offset), target: target, shown: offset)
        current.led = led
        let fronts = current.held.filter(\.isFront)
        guard !reduceMotion(), !fronts.isEmpty else {
            guard !led else { return false }   // nothing to show the fingers' work with: the caller steps instead
            scrolling = current
            land(current, at: target)
            return true
        }
        for front in fronts { current.pictures[front.ref.id] = keptPicture(of: front) }
        scrolling = current
        let id = current.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.giveUpAfter) { [weak self] in self?.giveUp(id) }
        // Photographing seven windows while the pictures glide takes the machine's time and makes the glide stutter, and the new
        // photographs have to be put on the layers in the middle of it. With a picture for every window already, the glide
        // runs on them alone; fresh ones are taken afterwards (`warm`), for the next scroll.
        if fronts.allSatisfy({ current.pictures[$0.ref.id] != nil }) {
            scrolling?.photographed = true
            coverIfReady()
        } else {
            snapshots.snapshots(of: fronts.map(\.ref)) { [weak self] images in self?.captured(images, id: id) }
        }
        return true
    }

    /// The focus went to a window in a zone beyond the screen's edge: scrolls straight to the nearest rest position that shows
    /// it, however many areas lie between. A scroll that runs when this is asked is followed by this one. False when no screen has
    /// the zone out of sight, or the windows are not free to be moved.
    @discardableResult
    func reveal(zone id: UUID) -> Bool {
        guard scrolling == nil else {
            revealing = id
            return false
        }
        let all = screens.screens()
        for screen in all {
            guard let (geometry, side) = planner.strip(of: screen, among: all), side != nil,
                  let placed = geometry.zones(offset: geometry.clamped(viewport.offset(for: screen.key))).first(where: { $0.id == id }),
                  !placed.isOnScreen else { continue }
            let edge: ScreenEdge = placed.rect.minX >= screen.axVisible.midX ? .right : .left
            let offset = geometry.clamped(viewport.offset(for: screen.key))
            let beyond = edge == .right ? geometry.rests.filter { $0 > offset + 0.5 } : geometry.rests.filter { $0 < offset - 0.5 }.reversed()
            guard let target = beyond.first(where: { rest in geometry.zones(offset: rest).first { $0.id == id }?.isOnScreen == true }) else { return false }
            return scroll(toward: edge, on: screen, to: target)
        }
        return false
    }

    /// A scroll has come to rest: the zone a focus change asked for is brought on, if it is not in view yet.
    private func rested() {
        if let id = revealing {
            revealing = nil
            reveal(zone: id)
        }
        onRest?()
    }

    /// The rest position after `offset` toward `edge`, if there is one.
    private func nextRest(from offset: CGFloat, toward edge: ScreenEdge, in geometry: StripGeometry) -> CGFloat? {
        edge == .right ? geometry.rests.first(where: { $0 > offset + 0.5 }) : geometry.rests.last(where: { $0 < offset - 0.5 })
    }

    /// A scroll that runs gets a new aim: the pictures of every window are on the stage already.
    private func carryOn(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        guard var current = scrolling, current.screen.key == screen.key, current.phase != .landing,
              let target = nextRest(from: current.target, toward: edge, in: current.geometry) else { return false }
        current.target = target
        if current.phase == .gliding {
            current.glideFrom = current.shown
            current.glideTo = target
            current.glideBegan = now()
        }
        scrolling = current
        return true
    }

    // MARK: Pictures

    /// Every window of the screen's zones, with its zone.
    private func held(of geometry: StripGeometry, at offset: CGFloat) -> [Held] {
        geometry.zones(offset: offset).flatMap { placed -> [Held] in
            guard let stack = coordinator.stacks[placed.id] else { return [] }
            return stack.refs.values.map {
                Held(ref: $0, zone: placed.id, rect: stack.rect, isFront: $0.id == stack.activeID, isParked: stack.isParked)
            }
        }
    }

    /// The photograph where the window stands: at its zone's corner, which is where windows are put. The place a photograph says
    /// the window was at is not used: the list it comes from is kept for a few seconds and does not know that the window has
    /// been moved since.
    private func placed(_ photograph: WindowPicture, in front: Held) -> WindowPicture {
        WindowPicture(image: photograph.image, frame: CGRect(origin: front.rect.origin, size: photograph.frame.size),
                      cornerRadius: photograph.cornerRadius)
    }

    /// Photographs of windows that were closed would otherwise stay for good.
    private func forgetOldPictures(at time: TimeInterval) {
        kept = kept.filter { time - $0.value.at < Self.keepPicturesFor }
    }

    /// An earlier photograph of the window, if it is recent.
    private func keptPicture(of front: Held) -> WindowPicture? {
        guard let entry = kept[front.ref.id], now() - entry.at < Self.keepPicturesFor else { return nil }
        return placed(entry.picture, in: front)
    }

    private func captured(_ images: [CGWindowID: WindowPicture], id: Int) {
        guard var current = scrolling, current.id == id else { return }
        let at = now()
        var fresh: [ScrollPicture] = []
        current.photographed = true
        for front in current.held where front.isFront {
            guard let image = images[front.ref.id] else { continue }
            kept[front.ref.id] = (image, at)
            let picture = placed(image, in: front)
            current.pictures[front.ref.id] = picture
            fresh.append(ScrollPicture(id: front.ref.id, picture: picture))
        }
        forgetOldPictures(at: at)
        scrolling = current
        switch current.phase {
        case .waiting: coverIfReady()
        case .covering, .gliding: stage.update(pictures: fresh)
        case .landing: break
        }
    }

    /// Covers the screen with the pictures as soon as there are some for every zone in view.
    private func coverIfReady() {
        guard var current = scrolling, current.phase == .waiting else { return }
        // Zones in view need their pictures; zones beyond the edge too, unless the photographs have come without them (then that
        // window only shows once the scroll is over).
        let fronts = current.held.filter(\.isFront)
        guard fronts.allSatisfy({ current.pictures[$0.ref.id] != nil || ($0.isParked && current.photographed) }) else { return }
        let pictures = fronts.compactMap { front in current.pictures[front.ref.id].map { ScrollPicture(id: front.ref.id, picture: $0) } }
        guard !pictures.isEmpty else { return }
        current.phase = .covering
        scrolling = current
        let id = current.id
        stage.begin(pictures: pictures, over: current.screen.axVisible) { [weak self] in self?.covered(id) }
    }

    private func giveUp(_ id: Int) {
        guard let current = scrolling, current.id == id, current.phase == .waiting else { return }
        land(current, at: current.target)
    }

    /// The pictures are on screen: the real windows wait at the display's edge, and the pictures glide on to the target.
    private func covered(_ id: Int) {
        guard var current = scrolling, current.id == id, current.phase == .covering else { return }
        for held in current.held {
            mover.move(held.ref, to: Parking.frame(for: held.rect, on: current.screen.cocoaFrame, side: current.side).origin)
        }
        coordinator.isScrolling = true
        refresher?.refreshZones()   // the pills go away
        current.phase = .gliding
        current.shown = current.start
        current.glideFrom = current.start
        current.glideTo = current.target
        current.glideBegan = now()
        scrolling = current
        if current.led {
            // The pictures follow the fingers, from where they are now; no clock moves them until the fingers lift.
            followFingers()
            return
        }
        startGliding()
    }

    private func startGliding() {
        guard !ticking else { return }
        ticking = true
        metronome { [weak self] in self?.frame() ?? false }
    }

    // MARK: Led by the fingers

    /// Two fingers came down: the layout of the screen under the pointer follows them, with everything beyond its edges, until they
    /// lift. False when this cannot be done (a scroll runs, nothing to scroll, motion is reduced): the caller steps on lifting.
    @discardableResult
    func beginLed() -> Bool {
        revealing = nil
        guard scrolling == nil else { return false }
        let all = screens.screens()
        guard let screen = all.first(where: { $0.cocoaFrame.contains(screens.pointerCocoa) }) ?? all.first,
              let (geometry, side) = planner.strip(of: screen, among: all), side != nil,
              geometry.range.lowerBound < geometry.range.upperBound else { return false }
        return scroll(toward: .right, on: screen, to: nil, led: true)
    }

    /// The fingers moved by `delta` points (to the right is positive: the content follows them, the zones beyond the left edge come in).
    func moveLed(by delta: CGFloat, at time: TimeInterval) {
        guard var current = scrolling, current.led, !current.released else { return }
        current.gesture.add(delta, at: time)
        scrolling = current
        if current.phase == .gliding { followFingers() }
    }

    /// The fingers lifted: the pictures glide on to the rest position the swipe chose.
    func endLed() {
        guard var current = scrolling, current.led, !current.released else { return }
        current.released = true
        scrolling = current
        if current.phase == .gliding { glideOn() }
    }

    /// Where the layout stands for the fingers' work so far: the start less what the content was taken, held in the range with a little
    /// give past its ends.
    private func ledPosition(_ current: Scrolling) -> CGFloat {
        let range = current.geometry.range
        let wanted = current.start - current.gesture.offset
        if wanted > range.upperBound { return range.upperBound + min((wanted - range.upperBound) * 0.28, 70) }
        if wanted < range.lowerBound { return range.lowerBound - min((range.lowerBound - wanted) * 0.28, 70) }
        return wanted
    }

    private func followFingers() {
        guard var current = scrolling, current.led, current.phase == .gliding else { return }
        current.shown = ledPosition(current)
        scrolling = current
        stage.follow(shift: current.start - current.shown)
        if current.released { glideOn() }
    }

    /// The pictures glide from where the fingers left them to the nearest rest position to where they would come to rest.
    private func glideOn() {
        guard var current = scrolling, current.led, current.phase == .gliding else { return }
        let wanted = current.start - current.gesture.landing
        let target = current.geometry.rests.min { abs($0 - wanted) < abs($1 - wanted) } ?? current.start
        current.target = target
        current.glideFrom = current.shown
        current.glideTo = target
        current.glideBegan = now()
        scrolling = current
        startGliding()
    }

    // MARK: Moving

    /// One frame of the display: the pictures glide on to the target.
    private func frame() -> Bool {
        guard var current = scrolling, current.phase == .gliding else {
            ticking = false
            return false
        }
        let progress = reduceMotion() ? 1 : min((now() - current.glideBegan) / Self.glide, 1)
        let eased = 1 - pow(1 - progress, 3)
        current.shown = current.glideFrom + (current.glideTo - current.glideFrom) * CGFloat(eased)
        scrolling = current
        stage.follow(shift: current.start - current.shown)
        guard progress >= 1 else { return true }
        ticking = false
        land(current, at: current.glideTo)
        return false
    }

    // MARK: Landing

    /// The windows go to their zones for the new position (written off the main thread, all together), the zones are worked
    /// out, and the pictures give way to the windows.
    private func land(_ current: Scrolling, at offset: CGFloat) {
        guard let now = scrolling, now.id == current.id else { return }
        scrolling?.phase = .landing
        viewport.set(offset, for: current.screen.key)
        let plan = planner.plan(on: screens.screens())
        for held in current.held {
            if let zone = plan[held.zone] { mover.move(held.ref, to: zone.frame.origin) }
        }
        mover.flush { [weak self] in self?.landed(current) }
    }

    /// The windows have been written.
    private func landed(_ current: Scrolling) {
        // The windows are looked at once more and set right where they are not: one that an app moved or resized meanwhile (or
        // that did not answer) is put back exactly, with its size. The pictures hide this.
        coordinator.isScrolling = false
        refresher?.refreshZones()
        guard current.phase == .gliding else {
            scrolling = nil
            rested()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.drawTime) { [weak self] in
            self?.stage.finish {
                self?.scrolling = nil
                self?.rested()
                // Apps that settle late (a window that fits itself to its new place) are looked at once more.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresher?.refreshZones() }
                // Fresh photographs for the next scroll, once the machine is quiet again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self?.warm() }
            }
        }
    }
}
