import CoreGraphics

/// One consistent look at which windows exist and are visible, taken once per check.
struct WindowSnapshot {
    let all: Set<CGWindowID>
    let onScreen: Set<CGWindowID>
    let currentSpaces: Set<UInt64>
}
