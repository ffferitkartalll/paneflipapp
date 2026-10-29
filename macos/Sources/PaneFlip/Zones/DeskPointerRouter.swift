import AppKit
import PaneFlipCore

/// Answers where the pointer goes at the edge of a display, from the displays as they stand on the desk. The plan is kept between the pointer's moves
/// (there are a thousand a second) and made again when the displays or the desk arrangement change. Without a desk arrangement set for every display, or
/// with PaneFlip switched off, the pointer is left alone.
final class DeskPointerRouter {
    private let screens: ScreenProviding
    private let arrangement: () -> DeskArrangement
    private let isOn: () -> Bool
    private var plan: (arrangement: DeskArrangement, pointer: DeskPointer?)?
    private var observer: NSObjectProtocol?

    init(screens: ScreenProviding, arrangement: @escaping () -> DeskArrangement, isOn: @escaping () -> Bool) {
        self.screens = screens
        self.arrangement = arrangement
        self.isOn = isOn
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.plan = nil
        }
    }

    deinit { observer.map(NotificationCenter.default.removeObserver) }

    func target(from point: CGPoint, delta: CGVector) -> CGPoint? {
        guard isOn() else { return nil }
        let desk = arrangement()
        if plan?.arrangement != desk || plan == nil { plan = (desk, makePointer(desk)) }
        return plan?.pointer?.target(from: point, delta: delta)
    }

    private func makePointer(_ desk: DeskArrangement) -> DeskPointer? {
        let displays = DeskSpace.distinct(screens.screens())
        let sizes = displays.map { (id: $0.displayID, size: $0.deskSize) }
        guard displays.count > 1, desk.isSet(for: sizes) else { return nil }
        let frames = desk.frames(of: sizes)
        return DeskPointer(displays: displays.compactMap { display in
            frames[display.displayID].map { DeskPointer.Display(id: display.displayID, frame: screens.flip(display.cocoaFrame), desk: $0) }
        })
    }
}
