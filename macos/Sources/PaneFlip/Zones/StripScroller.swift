import CoreGraphics
import Foundation
import PaneFlipCore

/// Scrolls the layout of the screen under the pointer, from the shortcut or the pointer resting at the screen's edge. Pictures of the
/// windows glide, moved by the render server (so they glide whatever the apps or the machine are doing); the real windows wait at
/// the display's edge meanwhile. Then the pictures glide on to the nearest rest position, the real windows
/// are put where they belong, and the pictures give way to them.
final class StripScroller {
    /// A distance of 1 moves the layout this many screen widths.
    private static let swipeToScreens = 1.0
    /// The scroll must be this long (a fraction of the screen) before anything is shown or moved.
    private static let threshold = 0.02
    /// How fast the pictures catch up with the fingers: they close all but a third of the gap in this long.
    private static let followTime: TimeInterval = 0.04
    /// How long the pictures glide on to the rest position once the fingers are up.
    private static let glide: TimeInterval = 0.3
    /// Pictures that have not come after this long are given up on: the windows then move at the end, without pictures.
    private static let giveUpAfter: TimeInterval = 1.5
    /// Pictures from an earlier swipe stand in for new ones this long, so the layout follows the fingers at once.
    private static let keepPicturesFor: TimeInterval = 120
    /// A swipe whose end never came is ended after this long, so the windows are never left waiting.
    private static let watchdog: TimeInterval = 10
    /// A frame or two for the windows to be drawn where they now stand, before the pictures go.
    private static let drawTime: TimeInterval = 0.05

    private enum Phase { case touching, waiting, covering, following, gliding, direct, landing }

    /// A window of the screen's zones, with where its zone stood when the swipe began.
    private struct Held {
        let ref: WindowRef
        let zone: UUID
        let rect: CGRect
        let isFront: Bool
        let isParked: Bool
    }

    private struct Swipe {
        let id: Int
        let screen: ScreenInfo
        let geometry: StripGeometry
        let side: Parking.Side
        let start: CGFloat
        let held: [Held]
        var pictures: [CGWindowID: WindowPicture] = [:]
        /// The photographs of this swipe have come (some window may be missing from them).
        var photographed = false
        var distance = 0.0
        var phase = Phase.touching
        var endVelocity: Double?
        /// Where the pictures are now, between the start and the fingers.
        var shown: CGFloat
        var glideFrom: CGFloat = 0
        var glideTo: CGFloat = 0
        var glideBegan: TimeInterval = 0
        /// Where a scroll by shortcut or edge is heading (nil for a swipe by distance).
        var target: CGFloat?
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
    private var swipe: Swipe?
    private var lastTick: TimeInterval = 0
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

    /// Photographs the windows in front in every zone of the screens that can scroll, so the first swipe already has
    /// pictures to show.
    func warm() {
        guard isRunning, settings.values.overflowZonesEnabled, settings.values.placementEnabled, !isBusy(), !reduceMotion() else { return }
        let all = screens.screens()
        for screen in all {
            guard let (geometry, side) = planner.strip(of: screen, among: all), side != nil,
                  geometry.range.lowerBound < geometry.range.upperBound else { continue }
            let fronts = held(of: geometry, at: geometry.clamped(viewport.offset(for: screen.key))).filter(\.isFront)
            snapshots.snapshots(of: fronts.map(\.ref)) { [weak self] images in
                guard let self else { return }
                let at = now()
                for (id, picture) in images { kept[id] = (picture, at) }
                self.forgetOldPictures(at: at)
            }
        }
    }

    /// A scroll as the fingers of a swipe would make it: begun, moved by a distance (a fraction of the screen, right is positive),
    /// ended with a velocity.
    enum Event {
        case began
        case moved(Double)
        case ended(velocity: Double)
    }

    func handle(_ event: Event) {
        switch event {
        case .began: begin()
        case .moved(let distance): moved(distance)
        case .ended(let velocity): ended(velocity)
        }
    }

    // MARK: Swipe

    private func begin(on forced: ScreenInfo? = nil) {
        guard swipe == nil, settings.values.placementEnabled, settings.values.overflowZonesEnabled, !isBusy() else { return }   // else the last scroll is still settling
        let all = screens.screens()
        guard let screen = forced ?? all.first(where: { $0.cocoaFrame.contains(screens.pointerCocoa) }),
              let (geometry, found) = planner.strip(of: screen, among: all), let side = found,
              geometry.range.lowerBound < geometry.range.upperBound
        else { return }
        count += 1
        let start = geometry.clamped(viewport.offset(for: screen.key))
        var current = Swipe(id: count, screen: screen, geometry: geometry, side: side, start: start,
                            held: held(of: geometry, at: start), shown: start)
        let fronts = current.held.filter(\.isFront)
        guard !reduceMotion(), !fronts.isEmpty else { swipe = current; return }
        // The photographs start now, so they are ready by the time the pictures are needed.
        for front in fronts { current.pictures[front.ref.id] = keptPicture(of: front) }
        // Photographing seven windows while the pictures glide takes the machine's time and makes the glide stutter, and the new
        // photographs have to be put on the layers in the middle of it. With a picture for every window already, the glide
        // runs on them alone; fresh ones are taken afterwards (`warm`), for the next scroll.
        if fronts.allSatisfy({ current.pictures[$0.ref.id] != nil }) {
            current.photographed = true
            swipe = current
            return
        }
        swipe = current
        let id = current.id
        snapshots.snapshots(of: fronts.map(\.ref)) { [weak self] images in self?.captured(images, id: id) }
    }

    /// Whether a scroll toward `edge` of `screen` would take the layout back toward its own place (the zones beyond the other
    /// edge are in view now).
    func isReturning(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        guard swipe == nil, let (geometry, side) = planner.strip(of: screen, among: screens.screens()), side != nil else { return false }
        let offset = geometry.clamped(viewport.offset(for: screen.key))
        return edge == .left ? offset > 0.5 : offset < -0.5
    }

    /// The shortcut: scrolls the screen under the pointer.
    @discardableResult
    func scroll(toward edge: ScreenEdge) -> Bool {
        let all = screens.screens()
        guard let screen = all.first(where: { $0.cocoaFrame.contains(screens.pointerCocoa) }) ?? all.first else { return false }
        return scroll(toward: edge, on: screen)
    }

    /// Brings the next rest position beyond `edge` of `screen` into view (a scroll as a swipe of the right length would make: the
    /// pictures glide, the windows land). False when there is nothing more that way, or the windows are not free to be moved.
    @discardableResult
    func scroll(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        guard settings.values.placementEnabled, !isBusy() else { return false }
        if swipe != nil { return carryOn(toward: edge, on: screen) }
        let all = screens.screens()
        guard let (geometry, side) = planner.strip(of: screen, among: all), side != nil else { return false }
        let offset = geometry.clamped(viewport.offset(for: screen.key))
        let rests = geometry.rests
        guard let target = edge == .right ? rests.first(where: { $0 > offset + 0.5 }) : rests.last(where: { $0 < offset - 0.5 }) else { return false }
        begin(on: screen)
        guard swipe != nil else { return false }
        swipe?.target = target
        handle(.moved(Double((offset - target) / (screen.axVisible.width * Self.swipeToScreens))))
        handle(.ended(velocity: 0))
        return true
    }

    /// A scroll that runs goes on to the next rest position the same way, or turns back when asked the other way: the pictures
    /// of every window are on the stage already, so it only gets a new aim.
    private func carryOn(toward edge: ScreenEdge, on screen: ScreenInfo) -> Bool {
        guard var current = swipe, current.screen.key == screen.key, let heading = current.target,
              [.waiting, .covering, .gliding].contains(current.phase) else { return false }
        let rests = current.geometry.rests
        guard let target = edge == .right ? rests.first(where: { $0 > heading + 0.5 }) : rests.last(where: { $0 < heading - 0.5 })
        else { return false }
        current.target = target
        if current.phase == .gliding {
            current.glideFrom = current.shown
            current.glideTo = target
            current.glideBegan = now()
        } else {
            // The pictures are not up yet: the end is still to come, and it lands at the rest position nearest to this distance.
            current.distance = Double((current.start - target) / (current.screen.axVisible.width * Self.swipeToScreens))
        }
        swipe = current
        return true
    }

    private func moved(_ distance: Double) {
        guard var current = swipe else { return }
        current.distance = distance
        swipe = current
        if current.phase == .touching, abs(distance) > Self.threshold { startCover() }
    }

    private func ended(_ velocity: Double) {
        guard var current = swipe else { return }
        switch current.phase {
        case .touching:
            swipe = nil
        case .waiting, .covering:
            current.endVelocity = velocity   // the pictures are not up yet: the end waits for them
            swipe = current
        case .following:
            startGlide(current, velocity: velocity)
        case .direct:
            land(current, at: rest(of: current, velocity: velocity))
        case .gliding, .landing:
            break
        }
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
        guard var current = swipe, current.id == id else { return }
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
        swipe = current
        switch current.phase {
        case .waiting: coverIfReady()
        case .covering, .following, .gliding: stage.update(pictures: fresh)
        default: break
        }
    }

    /// The fingers have moved: cover the screen with the pictures as soon as there are some for every zone in view.
    private func startCover() {
        guard var current = swipe else { return }
        guard !reduceMotion(), current.held.contains(where: \.isFront) else {
            current.phase = .direct
            swipe = current
            return
        }
        current.phase = .waiting
        swipe = current
        let id = current.id
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.giveUpAfter) { [weak self] in self?.giveUp(id) }
        coverIfReady()
    }

    private func coverIfReady() {
        guard var current = swipe, current.phase == .waiting else { return }
        // Zones in view need their pictures; zones beyond the edge too, unless the photographs have come without them (then that
        // window only shows once the scroll is over).
        let fronts = current.held.filter(\.isFront)
        guard fronts.allSatisfy({ current.pictures[$0.ref.id] != nil || ($0.isParked && current.photographed) }) else { return }
        let pictures = fronts.compactMap { front in current.pictures[front.ref.id].map { ScrollPicture(id: front.ref.id, picture: $0) } }
        guard !pictures.isEmpty else { return }
        current.phase = .covering
        swipe = current
        let id = current.id
        stage.begin(pictures: pictures, over: current.screen.axVisible) { [weak self] in self?.covered(id) }
    }

    private func giveUp(_ id: Int) {
        guard var current = swipe, current.id == id, current.phase == .waiting else { return }
        current.phase = .direct
        swipe = current
        if let velocity = current.endVelocity { land(current, at: rest(of: current, velocity: velocity)) }
    }

    /// The pictures are on screen: the real windows wait at the display's edge, and the pictures follow the fingers.
    private func covered(_ id: Int) {
        guard var current = swipe, current.id == id, current.phase == .covering else { return }
        for held in current.held {
            mover.move(held.ref, to: Parking.frame(for: held.rect, on: current.screen.cocoaFrame, side: current.side).origin)
        }
        coordinator.isScrolling = true
        refresher?.refreshZones()   // the pills go away
        current.phase = .following
        current.shown = current.start
        swipe = current
        if !ticking {
            ticking = true
            lastTick = now()
            metronome { [weak self] in self?.frame() ?? false }
        }
        if let velocity = current.endVelocity { return startGlide(current, velocity: velocity) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.watchdog) { [weak self] in
            if let stuck = self?.swipe, stuck.id == id, stuck.phase == .following { self?.startGlide(stuck, velocity: 0) }
        }
    }

    // MARK: Moving

    /// One frame of the display: the pictures ease towards the fingers, or glide on to the rest position.
    private func frame() -> Bool {
        guard var current = swipe, current.phase == .following || current.phase == .gliding else {
            ticking = false
            return false
        }
        let time = now()
        let elapsed = max(time - lastTick, 0)
        lastTick = time
        if current.phase == .following {
            // Catching up by the same share of the gap in the same time, whatever the frame rate.
            let share = reduceMotion() ? 1 : 1 - CGFloat(exp(-elapsed / Self.followTime))
            current.shown += (reach(current) - current.shown) * share
            swipe = current
            stage.follow(shift: current.start - current.shown)
            return true
        }
        let progress = reduceMotion() ? 1 : min((time - current.glideBegan) / Self.glide, 1)
        let eased = 1 - pow(1 - progress, 3)
        current.shown = current.glideFrom + (current.glideTo - current.glideFrom) * CGFloat(eased)
        swipe = current
        stage.follow(shift: current.start - current.shown)
        guard progress >= 1 else { return true }
        ticking = false
        land(current, at: current.glideTo)
        return false
    }

    private func startGlide(_ current: Swipe, velocity: Double) {
        var gliding = current
        gliding.phase = .gliding
        gliding.glideFrom = current.shown
        gliding.glideTo = rest(of: current, velocity: velocity)
        gliding.glideBegan = now()
        swipe = gliding
    }

    /// Where the screen is, with the fingers at their distance.
    private func reach(_ swipe: Swipe) -> CGFloat {
        swipe.geometry.clamped(swipe.start - swipe.distance * swipe.screen.axVisible.width * Self.swipeToScreens)
    }

    private func rest(of swipe: Swipe, velocity: Double) -> CGFloat {
        swipe.geometry.rest(from: reach(swipe), velocity: -velocity * swipe.screen.axVisible.width * Self.swipeToScreens)
    }

    // MARK: Landing

    /// The windows go to their zones for the new position (written off the main thread, all together), the zones are worked
    /// out, and the pictures give way to the windows.
    private func land(_ current: Swipe, at offset: CGFloat) {
        guard let now = swipe, now.id == current.id else { return }
        swipe?.phase = .landing
        viewport.set(offset, for: current.screen.key)
        let plan = planner.plan(on: screens.screens())
        for held in current.held {
            if let zone = plan[held.zone] { mover.move(held.ref, to: zone.frame.origin) }
        }
        mover.flush { [weak self] in self?.landed(current) }
    }

    /// The windows have been written.
    private func landed(_ current: Swipe) {
        // The windows are looked at once more and set right where they are not: one that an app moved or resized meanwhile (or
        // that did not answer) is put back exactly, with its size. The pictures hide this.
        coordinator.isScrolling = false
        refresher?.refreshZones()
        let covered = current.phase == .gliding || current.phase == .following
        guard covered else {
            swipe = nil
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.drawTime) { [weak self] in
            self?.stage.finish {
                self?.swipe = nil
                // Apps that settle late (a window that fits itself to its new place) are looked at once more.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresher?.refreshZones() }
                // Fresh photographs for the next scroll, once the machine is quiet again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self?.warm() }
            }
        }
    }
}
