import SwiftUI

extension EnvironmentValues {
    /// The room inside the window or sheet a sheet opens over, its own margins left out: no sheet is larger than it.
    @Entry var modalRoom = CGSize(width: 10_000, height: 10_000)
}
