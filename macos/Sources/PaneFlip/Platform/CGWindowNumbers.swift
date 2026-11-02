import CoreGraphics

/// The numbers of the windows the system lists, front to back, with no description of each window to build and send over.
enum CGWindowNumbers {
    /// `CGWindowListCreate`, as an array of raw values: Swift has no import for it.
    @_silgen_name("CGWindowListCreate")
    private static func list(_ option: UInt32, _ relativeTo: UInt32) -> Unmanaged<CFArray>?

    static func ids(_ option: CGWindowListOption) -> [CGWindowID] {
        guard let ids = list(option.rawValue, kCGNullWindowID)?.takeRetainedValue() else { return [] }
        return (0..<CFArrayGetCount(ids)).map { CGWindowID(UInt(bitPattern: CFArrayGetValueAtIndex(ids, $0))) }
    }
}
