import AppKit
import SwiftUI

/// Moves how far a grid has opened (`ZoneWindowsModel.appear`, 0 with the pictures over their windows, 1 with the cards in their places) frame by frame, by hand: SwiftUI's own animations
/// add up with the one that runs (a slide that is cut short goes on under what comes after it and pulls the pictures past where they were held, out of their zone), and a slide's end
/// is told when it is cut short. Here there is one value, it is always from 0 to 1, and what is drawn is what it says.
final class AppearDriver: NSObject {
    /// Mission Control goes both ways with one motion: a quick start and a long, soft landing, the same time in and out (the system gives no value for it; this is the look of it).
    static let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.3, y: 0), endControlPoint: UnitPoint(x: 0.15, y: 1))
    static let slideTime: TimeInterval = 0.38
    /// The fingers' steps are glided to in about this time: the trackpad tells of them less often, and less evenly, than the display draws.
    private static let followTime: TimeInterval = 0.035

    private(set) var value: CGFloat = 0

    private enum Motion {
        case rest
        case follow(goal: CGFloat)
        case slide(from: CGFloat, to: CGFloat, start: TimeInterval, speed: CGFloat, then: () -> Void)
    }
    private var motion = Motion.rest
    private var lastStep: TimeInterval
    /// How fast it was going at its last step (per second), and when: a slide that takes over from the fingers goes on at that speed instead of stopping and starting again.
    private var speed: CGFloat = 0
    private var movedAt: TimeInterval = 0
    private var link: CADisplayLink?
    private let clock: () -> TimeInterval
    private let apply: (CGFloat) -> Void
    /// False in tests: they take the steps themselves.
    private let runsItself: Bool

    init(runsItself: Bool = true, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, apply: @escaping (CGFloat) -> Void) {
        self.runsItself = runsItself
        self.clock = clock
        self.apply = apply
        lastStep = clock()
        super.init()
    }

    /// Back to 0, at rest: the grid was torn down.
    func reset() {
        stop()
        set(0)
        speed = 0
    }

    /// Stops where it is: the fingers have it from here (or nothing moves it).
    func hold() { stop() }

    /// Glides to where the fingers are, and never past it.
    func follow(to goal: CGFloat) {
        // Only a new following starts the clock: every new goal used to reset it, so a frame right after an event moved by almost nothing (the stepwise look).
        if case .follow = motion {} else { lastStep = clock() }
        motion = .follow(goal: Self.clamped(goal))
        start()
    }

    /// Slides to `target` from where it is, in the same time whatever the way; `then` is called when it gets there (not when something else takes it over meanwhile).
    func slide(to target: CGFloat, then: @escaping () -> Void = {}) {
        let to = Self.clamped(target)
        guard abs(to - value) > 0.001 else {
            stop()
            set(to)
            DispatchQueue.main.async(execute: then)
            return
        }
        let now = clock()
        motion = .slide(from: value, to: to, start: now, speed: now - movedAt < 0.05 ? speed : 0, then: then)
        start()
    }

    /// One frame.
    func step() {
        let now = clock()
        switch motion {
        case .rest:
            stop()
        case .follow(let goal):
            let share = 1 - exp(-(now - lastStep) / Self.followTime)
            lastStep = now
            var next = value + (goal - value) * CGFloat(share)
            if abs(goal - next) < 0.0005 {
                next = goal
                stop()
            }
            set(next)
        case .slide(let from, let to, let began, let speed0, let then):
            let progress = (now - began) / Self.slideTime
            if progress >= 1 {
                stop()
                set(to)
                then()
            } else {
                let p = CGFloat(max(progress, 0))
                // The curve starts at rest; this term (nothing at either end) gives the slide the speed it takes over with.
                set(from + (to - from) * CGFloat(Self.curve.value(at: Double(p))) + speed0 * CGFloat(Self.slideTime) * p * (1 - p) * (1 - p))
            }
        }
    }

    private func set(_ next: CGFloat) {
        let now = clock()
        let clamped = Self.clamped(next)
        if now > movedAt { speed = (clamped - value) / CGFloat(now - movedAt) }
        movedAt = now
        value = clamped
        apply(value)
    }

    private func start() {
        guard runsItself, link == nil, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // One step for every frame the display draws (a timer at a fixed rate would not keep step with it).
        let frames = screen.displayLink(target: self, selector: #selector(frame(_:)))
        frames.add(to: .main, forMode: .common)   // the trackpad's own tracking must not stop it
        link = frames
    }

    @objc private func frame(_ link: CADisplayLink) { step() }

    private func stop() {
        motion = .rest
        link?.invalidate()
        link = nil
    }

    private static func clamped(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }
}
