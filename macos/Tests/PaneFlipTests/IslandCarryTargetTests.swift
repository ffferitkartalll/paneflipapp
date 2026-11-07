import XCTest

final class IslandCarryTargetTests: XCTestCase {
    func testTheZonesStayLitOverTheScreenAndOnlyTheOneUnderThePointerIsMarked() {
        let zone = UUID()
        XCTAssertFalse(IslandCarryTarget.island.lighting.lit)
        XCTAssertEqual(IslandCarryTarget.screen(zone).lighting.zone, zone)
        XCTAssertTrue(IslandCarryTarget.screen(zone).lighting.lit)
        // In a gap between zones (the card would be taken out) they stay lit, none marked.
        XCTAssertTrue(IslandCarryTarget.takeOut.lighting.lit)
        XCTAssertNil(IslandCarryTarget.takeOut.lighting.zone)
    }
}
