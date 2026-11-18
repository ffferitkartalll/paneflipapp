import CoreGraphics

extension StackCoordinator {
    /// Takes windows out of their zones (the memory is the caller's business) and returns the ones that were in a zone.
    func detach(windows ids: [CGWindowID]) -> [WindowRef] {
        let refs = ids.compactMap { id in stacks.values.lazy.compactMap { $0.refs[id] }.first }
        ids.forEach(removeFromStack(window:))
        return refs
    }
}
