/// Whether the Caps Lock key (mapped to F18) is down. The tap that swallows the key keeps it: the hardware state is not trusted for a key
/// whose release the app has taken, it can stay down.
final class CapsLockKeyState {
    var isDown = false
}
