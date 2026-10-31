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
    /// A layout this close to a rest is at it, for fingers that catch it on its way.
    private static let arrived: CGFloat = 80

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
        /// The layout offset the pictures on the stage stand for: where this scroll began, or, for one that took over from another while it
        /// landed, where that one began (the pictures were not laid out again).
        var origin: CGFloat = 0
        /// How far the pictures have moved from where they stand on the stage.
        var shift: CGFloat { origin - shown }
        /// The pictures were on the stage when it landed: it can be taken over.
        var staged = false
        /// Fingers caught a glide on its way: the rest it was heading to, and where the pictures stood when they were caught.
        var heading: CGFloat?
        var caughtAt: CGFloat = 0
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
    /// A glide of the layout begins or is given a new aim: the screen, how far it goes (from, to: layout offsets; from is nil when it goes on from where it is).
    /// The fingers move the layout of a screen: its layout offset. Called as often as the pictures move.
    var onFollow: ((ScreenInfo, _ offset: CGFloat) -> Void)?
    var onGlide: ((ScreenInfo, _ from: CGFloat?, _ to: CGFloat) -> Void)?
    /// The zone a focus change asked the scroll to bring into view; each scroll that comes to rest goes on until it shows.
    private var revealing: UUID?
    /// Presses that came while a scroll landed, to be done when it is over.
    private var queued: [(edge: ScreenEdge, screen: ScreenInfo)] = []
    private static let mostQueued = 3
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
        guard isRunning, settings.values.overflowZonesEnabled, settings.values.placementEnabled, !isBusy(), !reduceMotion(), !coordinator.isMoving else { return }
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
        if let current = scrolling {
            if current.phase == .landing, current.screen.key == screen.key, takeOverLanding(led: false) {
                let carried = carryOn(toward: edge, on: screen)
                startGliding()   // to the new aim; with none, back to the rest it came to
                return carried
            }
            if carryOn(toward: edge, on: screen) { return true }
            // A scroll that lands cannot be given a new aim: the press waits for the landing and goes on from there (a few at most, so
            // that a key held down does not go on after it is let go). Without a rest beyond, there is nothing to wait for.
            guard current.phase == .landing, current.screen.key == screen.key, queued.count < Self.mostQueued,
                  nextRest(from: current.target, toward: edge, in: current.geometry) != nil else { return false }
            queued.append((edge, screen))
            return true
        }
        let all = screens.screens()
        guard let (geometry, found) = planner.strip(of: screen, among: all), let side = found else { return false }
        let offset = geometry.clamped(viewport.offset(for: screen.key))
        guard let target = led ? offset : wanted ?? nextRest(from: offset, toward: edge, in: geometry) else { return false }
        count += 1
        var current = Scrolling(id: count, screen: screen, geometry: geometry, side: side, start: offset,
                                held: held(of: geometry, at: offset), target: target, shown: offset)
        current.led = led
        current.origin = offset
        // The fingers cannot take the layout past its first and its last rest: nothing of the ends gives way, and going back is followed at once.
        if led { current.gesture.limit(to: offset - geometry.range.upperBound ... offset - geometry.range.lowerBound) }
        let fronts = current.held.filter(\.isFront)
        guard !reduceMotion() else {
            guard !led else { return false }   // nothing to show the fingers' work with: the caller steps instead
            scrolling = current
            land(current, at: target)
            return true
        }
        // No window in any zone of the screen: nothing to photograph or to park. The frame of the island still glides
        // (or follow the fingers), and the layout goes there when they are done.
        guard !fronts.isEmpty else {
            beginGliding(current)
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
    /// it, however many areas lie between. The focus went to a zone of the screen itself while the layout is scrolled away from it: scrolls back, so that
    /// no zone beyond the edge is in view. A scroll that runs when this is asked is followed by this one. False when no screen has
    /// the zone out of sight, or the windows are not free to be moved.
    @discardableResult
    func reveal(zone id: UUID, standsAt: ((CGRect) -> Void)? = nil) -> Bool {
        if let current = scrolling {
            // Presses of the shortcut that follow quickly go straight on: the scroll that runs is given a new aim, the rest that shows the zone, instead of the
            // press waiting for the landing and starting a scroll of its own after it.
            var aim = rest(showing: id, from: current.target, on: current.screen, geometry: current.geometry)
            // A scroll that lands is taken over, as a press of the scroll shortcut does: the zone is not in view where it comes to rest.
            if current.phase == .landing, aim != nil, !takeOverLanding(led: false) { aim = nil }
            if let aim {
                aimAt(aim.rest)
                startGliding()
            }
            // The zone stands in view at the rest the scroll heads for (the one it was given, or the one it already has): it tells where, at once. A scroll that
            // lands has nothing to wait for: a zone in view is brought forward at once.
            let target = aim?.rest ?? current.target
            if !current.led, aim != nil || current.phase != .landing && current.geometry.zones(offset: target).first(where: { $0.id == id })?.isOnScreen == true,
               let rect = planner.rect(of: id, at: target, on: current.screen, among: screens.screens()) {
                standsAt?(rect)
                return true
            }
            revealing = id
            return false
        }
        let all = screens.screens()
        for screen in all {
            guard let (geometry, side) = planner.strip(of: screen, among: all), side != nil else { continue }
            let offset = geometry.clamped(viewport.offset(for: screen.key))
            guard geometry.zones(offset: offset).contains(where: { $0.id == id }) else { continue }
            guard let aim = rest(showing: id, from: offset, on: screen, geometry: geometry) else { return false }
            let started = scroll(toward: aim.edge, on: screen, to: aim.rest)
            // Where the zone will stand when the scroll is over, told as the scroll starts.
            if started, let rect = planner.rect(of: id, at: aim.rest, on: screen, among: all) { standsAt?(rect) }
            return started
        }
        return false
    }

    /// The nearest rest position beyond `offset` that shows the zone (all of it, else any of it), and the edge it lies toward; nil when the zone is in view at
    /// `offset` or no rest shows it.
    private func rest(showing id: UUID, from offset: CGFloat, on screen: ScreenInfo, geometry: StripGeometry) -> (edge: ScreenEdge, rest: CGFloat)? {
        if let home = homeRest(of: id, from: offset, geometry: geometry) { return (offset > home ? .left : .right, home) }
        guard let placed = geometry.zones(offset: offset).first(where: { $0.id == id }), !placed.isOnScreen else { return nil }
        let edge: ScreenEdge = placed.rect.minX >= screen.axVisible.midX ? .right : .left
        let beyond = edge == .right ? geometry.rests.filter { $0 > offset + 0.5 } : geometry.rests.filter { $0 < offset - 0.5 }.reversed()
        // The nearest rest that shows the whole zone, else the nearest that shows any of it.
        let shown = beyond.compactMap { rest in geometry.zones(offset: rest).first { $0.id == id }.map { (rest, $0) } }.filter { $0.1.isOnScreen }
        let whole = shown.first { $0.1.rect.minX >= screen.axVisible.minX - 0.5 && $0.1.rect.maxX <= screen.axVisible.maxX + 0.5 }
        return (whole ?? shown.first).map { (edge, $0.0) }
    }

    /// The rest position of the screen itself (no zone beyond its edges in view), when `id` is a zone of the screen and the layout is scrolled away from it.
    private func homeRest(of id: UUID, from offset: CGFloat, geometry: StripGeometry) -> CGFloat? {
        guard abs(offset) > 0.5, geometry.zones(offset: 0).first(where: { $0.id == id })?.isOnScreen == true else { return nil }
        return 0
    }

    /// The scroll that runs heads for another rest position.
    private func aimAt(_ target: CGFloat) {
        guard var current = scrolling else { return }
        current.target = target
        if current.phase == .gliding {
            current.glideFrom = current.shown
            current.glideTo = target
            current.glideBegan = now()
            onGlide?(current.screen, nil, target)
        }
        scrolling = current
    }

    /// A scroll has come to rest: the zone a focus change asked for is brought on, if it is not in view yet.
    private func rested() {
        if let id = revealing {
            revealing = nil
            reveal(zone: id)
        }
        // The presses that came while it landed: the first starts a scroll, the rest give it a new aim, one rest further each.
        if scrolling == nil, !queued.isEmpty {
            let pending = queued
            queued = []
            for next in pending { _ = scroll(toward: next.edge, on: next.screen, to: nil) }
        }
        onRest?()
    }

    /// The rest position after `offset` toward `edge`, if there is one.
    private func nextRest(from offset: CGFloat, toward edge: ScreenEdge, in geometry: StripGeometry) -> CGFloat? {
        edge == .right ? geometry.rests.first(where: { $0 > offset + 0.5 }) : geometry.rests.last(where: { $0 < offset - 0.5 })
    }

    /// A scroll that runs gets a new aim: the pictures of every window are on the stage already.
    private func carryOn(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        guard let current = scrolling, current.screen.key == screen.key, current.phase != .landing,
              let target = nextRest(from: current.target, toward: edge, in: current.geometry) else { return false }
        aimAt(target)
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
        guard let current = scrolling, current.id == id, current.phase == .covering else { return }
        for held in current.held {
            mover.move(held.ref, to: Parking.frame(for: held.rect, on: current.screen.cocoaFrame, side: current.side).origin)
        }
        beginGliding(current)
    }

    /// The layout glides from where it stands to the target, or follows the fingers that lead it. The pictures, when there are any, are on the stage.
    private func beginGliding(_ started: Scrolling) {
        var current = started
        coordinator.isScrolling = true
        refresher?.refreshZones()   // the island follows
        current.phase = .gliding
        current.shown = current.start
        current.glideFrom = current.start
        current.glideTo = current.target
        current.glideBegan = now()
        scrolling = current
        if !current.led { onGlide?(current.screen, current.start, current.target) }
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
    /// lift. False when this cannot be done (a scroll runs, nothing to scroll, motion is reduced): the caller steps on lifting. A screen with no
    /// window is followed too: the frame of the island and the map of the strip show the fingers' work.
    @discardableResult
    func beginLed() -> Bool {
        revealing = nil
        // Fingers that come down while a scroll is on its way take it over where it is: one that fingers let go of, and also one a
        // key, the wheel over the island or an earlier swipe started. Not while it lands: the windows are being put in their places then.
        if var current = scrolling, current.phase != .landing, !(current.led && !current.released) {
            if !current.led {
                current.led = true
                current.gesture = ScrubGesture()
                current.gesture.limit(to: current.start - current.geometry.range.upperBound ... current.start - current.geometry.range.lowerBound)
            }
            current.released = false
            current.heading = current.glideTo
            current.caughtAt = current.shown
            current.gesture.resume(at: current.start - current.shown)
            scrolling = current
            onFollow?(current.screen, current.shown)   // the pictures stop here: so does the frame of the island
            return true
        }
        if scrolling?.phase == .landing { return takeOverLanding(led: true) }
        guard scrolling == nil else { return false }
        let all = screens.screens()
        guard let screen = all.first(where: { $0.cocoaFrame.contains(screens.pointerCocoa) }) ?? all.first,
              let (geometry, side) = planner.strip(of: screen, among: all), side != nil,
              geometry.range.lowerBound < geometry.range.upperBound else { return false }
        return scroll(toward: .right, on: screen, to: nil, led: true)
    }

    /// A scroll that lands (its windows are being put in their places, the pictures are about to give way) is taken over by fingers or a
    /// press: the pictures stay on the stage as they are, the windows beneath are parked at the display's edge again, and the new scroll
    /// goes on from where the old one came to rest. False when it cannot be done (the old one had no pictures).
    private func takeOverLanding(led: Bool) -> Bool {
        guard let current = scrolling, current.phase == .landing, current.staged else { return false }
        let rest = current.glideTo
        stage.keep()
        count += 1
        var next = Scrolling(id: count, screen: current.screen, geometry: current.geometry, side: current.side, start: rest,
                             held: current.held, target: rest, shown: rest)
        next.origin = current.origin
        next.pictures = current.pictures
        next.photographed = true
        next.staged = true
        next.phase = .gliding
        next.glideFrom = rest
        next.glideTo = rest
        next.glideBegan = now()
        if led {
            next.led = true
            next.gesture.limit(to: rest - current.geometry.range.upperBound ... rest - current.geometry.range.lowerBound)
        }
        for held in next.held {
            mover.move(held.ref, to: Parking.frame(for: held.rect, on: next.screen.cocoaFrame, side: next.side).origin)
        }
        coordinator.isScrolling = true
        refresher?.refreshZones()   // the island follows
        scrolling = next
        if led { followFingers() }
        return true
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

    /// Where the layout stands for the fingers' work so far: the start less what the content was taken (the gesture keeps that inside the range).
    private func ledPosition(_ current: Scrolling) -> CGFloat { current.start - current.gesture.offset }

    private func followFingers() {
        guard var current = scrolling, current.led, current.phase == .gliding else { return }
        current.shown = ledPosition(current)
        scrolling = current
        stage.follow(shift: current.shift)
        onFollow?(current.screen, current.shown)
        if current.released { glideOn() }
    }

    /// The pictures glide from where the fingers left them to the nearest rest position to where they would come to rest.
    private func glideOn() {
        guard var current = scrolling, current.led, current.phase == .gliding else { return }
        let wanted = current.start - current.gesture.landing
        var target = current.geometry.rests.min { abs($0 - wanted) < abs($1 - wanted) } ?? current.start
        // A flick, however small, goes on to the next rest the way it went: one that falls just short of half the way would come back. The next one
        // from where the fingers took hold: where the layout rested, or, when they caught a glide, where that was (a glide that has all but arrived has arrived).
        if current.gesture.isFlick {
            let from = current.heading == nil ? current.start : current.caughtAt
            let beyond = current.geometry.rests.filter { wanted > from ? $0 > from + Self.arrived : $0 < from - Self.arrived }
            if let next = beyond.min(by: { abs($0 - wanted) < abs($1 - wanted) }) { target = next }
        }
        // Fingers that caught a glide, rested or went on the way it was going: it goes on to the rest it was heading to, not back to the one it came from.
        if !current.gesture.isFlick, let heading = current.heading {
            let moved = current.shown - current.caughtAt
            if abs(moved) < ScrubGesture.flickDistance || moved * (heading - current.caughtAt) > 0 { target = heading }
        }
        current.target = target
        current.glideFrom = current.shown
        current.glideTo = target
        current.glideBegan = now()
        scrolling = current
        onGlide?(current.screen, current.shown, target)
        startGliding()
    }

    // MARK: Moving

    /// One frame of the display: the pictures glide on to the target.
    private func frame() -> Bool {
        // A glide the fingers have taken over again waits for them.
        guard var current = scrolling, current.phase == .gliding, !(current.led && !current.released) else {
            ticking = false
            return false
        }
        let progress = reduceMotion() ? 1 : min((now() - current.glideBegan) / Self.glide, 1)
        let eased = 1 - pow(1 - progress, 3)
        current.shown = current.glideFrom + (current.glideTo - current.glideFrom) * CGFloat(eased)
        scrolling = current
        stage.follow(shift: current.shift)
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
        scrolling?.staged = current.phase == .gliding
        viewport.set(offset, for: current.screen.key)
        let plan = planner.plan(on: screens.screens())
        coordinator.showFocusFrame(in: plan)   // the zone shows at once, while the pictures still cover the screen
        for held in current.held {
            if let zone = plan[held.zone] { mover.move(held.ref, to: zone.frame.origin) }
        }
        mover.flush { [weak self] in self?.landed(current) }
    }

    /// The windows have been written.
    private func landed(_ current: Scrolling) {
        guard scrolling?.id == current.id else { return }   // taken over meanwhile
        // The windows are looked at once more and set right where they are not: one that an app moved or resized meanwhile (or
        // that did not answer) is put back exactly, with its size. The pictures hide this.
        coordinator.isScrolling = false
        refresher?.refreshZones()
        coordinator.finishFocusBeyondTheEdge()   // the windows stand in their places: the pictures hide the window that comes forward
        guard current.phase == .gliding else {
            scrolling = nil
            rested()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.drawTime) { [weak self] in
            guard self?.scrolling?.id == current.id else { return }   // taken over meanwhile
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
