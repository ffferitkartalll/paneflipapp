import Foundation

/// PaneFlip lives in the menu bar only, but while one of its own windows is open it should behave like a regular
/// app: a Dock icon and its name at the left of the menu bar. Windows report when they open and close; the
/// policy is "regular" while at least one is open.
protocol ActivationPolicyControlling: AnyObject {
    func windowDidOpen(_ window: ObjectIdentifier)
    func windowDidClose(_ window: ObjectIdentifier)
}
