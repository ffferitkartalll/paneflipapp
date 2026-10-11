// swift-tools-version:6.0
import PackageDescription

// The macOS app itself is an Xcode project generated from project.yml (an app needs a real .app bundle:
// bundle identifier, Info.plist, signing). This package holds the part that needs no bundle: the domain
// module and its unit tests, so `swift build` and `swift test` stay fast and AppKit-free.
let package = Package(
    name: "PaneFlip",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "PaneFlipCore", targets: ["PaneFlipCore"]),
    ],
    targets: [
        // Pure domain: layouts, stack memory, settings model. No AppKit, no Accessibility: unit-testable.
        .target(name: "PaneFlipCore", path: "Sources/PaneFlipCore"),
        .testTarget(name: "PaneFlipCoreTests", dependencies: ["PaneFlipCore"], path: "Tests/PaneFlipCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
