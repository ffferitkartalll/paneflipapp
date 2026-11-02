import Foundation

extension SettingsValues {
    /// These values after Caps Lock was switched as a modifier key (`capsLockAsModifier` is already the new state): a shortcut that is
    /// still the standard one of the former state takes the standard one of the new state, and, when Caps Lock is no longer a modifier
    /// key, so does one that uses it. The shortcuts the person chose otherwise stay.
    func switchingStandardShortcuts(wasCapsLock: Bool) -> SettingsValues {
        var result = self
        let former = StandardShortcuts.values(capsLock: wasCapsLock)
        for (path, standard) in StandardShortcuts.values(capsLock: capsLockAsModifier) {
            let current = self[keyPath: path]
            let usesCapsLock = current.keys.contains { $0.code == KeyChord.capsLockKeyCode }
            if current == former[path] || (usesCapsLock && !capsLockAsModifier) { result[keyPath: path] = standard }
        }
        return result
    }
}
