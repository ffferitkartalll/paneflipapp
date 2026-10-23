import Foundation

/// A shape a new layout can start from; the editor takes it from there. Each call of `root` makes a tree of its own, so
/// the zones of two layouts never share an identity.
public struct LayoutPreset: Identifiable {
    public let id: String
    private let make: () -> LayoutNode

    public var root: LayoutNode { make() }

    private init(_ id: String, _ make: @escaping () -> LayoutNode) {
        self.id = id
        self.make = make
    }

    public static let single = LayoutPreset("single") { zone }

    /// The shapes offered when a layout is added: every shape there is, plainest first. A screen is offered `suggested(for:)`.
    public static let all: [LayoutPreset] = [
        LayoutPreset("columns2") { columns(2) },
        LayoutPreset("columns3") { columns(3) },
        LayoutPreset("columns4") { columns(4) },
        LayoutPreset("rows2") { rows(2) },
        LayoutPreset("rows3") { rows(3) },
        LayoutPreset("rows4") { rows(4) },
        LayoutPreset("grid2x2") { grid(rows: 2, columns: 2) },
        LayoutPreset("grid2x3") { grid(rows: 2, columns: 3) },
        LayoutPreset("grid3x2") { grid(rows: 3, columns: 2) },
        LayoutPreset("grid3x3") { grid(rows: 3, columns: 3) },
        LayoutPreset("mainLeft") { beside(0.7, zone, zone) },
        LayoutPreset("mainRight") { beside(0.3, zone, zone) },
        LayoutPreset("mainTop") { above(0.7, zone, zone) },
        LayoutPreset("centre") { beside(0.25, zone, beside(2.0 / 3, zone, zone)) },
        LayoutPreset("mainLeftTwoColumns") { beside(0.5, zone, columns(2)) },
        LayoutPreset("mainLeftStackedRight") { beside(0.65, zone, above(0.5, zone, zone)) },
        LayoutPreset("stackedLeftMainRight") { beside(0.35, above(0.5, zone, zone), zone) },
        LayoutPreset("mainLeftThreeRight") { beside(0.6, zone, rows(3)) },
        LayoutPreset("mainTopThreeBelow") { above(0.6, zone, columns(3)) },
        LayoutPreset("bannerTop") { above(0.3, zone, columns(2)) },
        LayoutPreset("bannerBottom") { above(0.7, columns(2), zone) },
    ]

    /// The shapes that make sense for a screen of this shape (very wide, wide, nearly square, upright), the best first.
    public static func suggested(for screen: CGSize) -> [LayoutPreset] {
        let aspect = screen.width / max(screen.height, 1)
        let ids: [String]
        switch aspect {
        case 2...:
            ids = ["columns3", "centre", "columns2", "columns4", "mainLeft", "mainRight", "mainLeftTwoColumns", "grid2x2", "grid2x3",
                   "mainLeftStackedRight", "stackedLeftMainRight"]
        case 1.3..<2:
            ids = ["columns2", "grid2x2", "columns3", "mainLeft", "mainRight", "mainLeftTwoColumns", "mainLeftStackedRight",
                   "stackedLeftMainRight", "mainLeftThreeRight", "centre", "rows2", "mainTop", "bannerTop", "grid2x3", "mainTopThreeBelow"]
        case 0.8..<1.3:
            ids = ["grid2x2", "columns2", "rows2", "mainLeft", "mainTop", "mainLeftStackedRight", "columns3", "rows3", "bannerTop",
                   "bannerBottom", "grid3x3"]
        default:
            ids = ["rows2", "rows3", "rows4", "mainTop", "mainTopThreeBelow", "bannerTop", "bannerBottom", "grid3x2", "grid2x2", "columns2"]
        }
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    // MARK: Building blocks

    private static var zone: LayoutNode { .leaf(UUID()) }

    private static func beside(_ ratio: Double, _ first: LayoutNode, _ second: LayoutNode) -> LayoutNode {
        .split(id: UUID(), sideBySide: true, ratio: ratio, first: first, second: second)
    }

    private static func above(_ ratio: Double, _ first: LayoutNode, _ second: LayoutNode) -> LayoutNode {
        .split(id: UUID(), sideBySide: false, ratio: ratio, first: first, second: second)
    }

    /// `count` equal columns: each split leaves one column to the first part and the rest to the second.
    private static func columns(_ count: Int) -> LayoutNode {
        count == 1 ? zone : beside(1 / Double(count), zone, columns(count - 1))
    }

    private static func rows(_ count: Int) -> LayoutNode {
        count == 1 ? zone : above(1 / Double(count), zone, rows(count - 1))
    }

    private static func grid(rows count: Int, columns width: Int) -> LayoutNode {
        count == 1 ? columns(width) : above(1 / Double(count), columns(width), grid(rows: count - 1, columns: width))
    }
}
