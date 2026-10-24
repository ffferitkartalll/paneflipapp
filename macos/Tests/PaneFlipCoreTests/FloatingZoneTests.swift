import XCTest
import CoreGraphics
@testable import PaneFlipCore

final class FloatingZoneTests: XCTestCase {
    func testItStandsInTheMiddleOfItsHostWithHalfItsWidthAndHeightByDefault() {
        let zone = FloatingZone(host: UUID())
        XCTAssertEqual(zone.rect(over: CGRect(x: 100, y: 0, width: 800, height: 600)), CGRect(x: 300, y: 150, width: 400, height: 300))
    }

    func testItsSizeStaysBetweenAQuarterAndThreeQuarters() {
        XCTAssertEqual(FloatingZone(host: UUID(), scale: 0.1).scale, 0.25)
        XCTAssertEqual(FloatingZone(host: UUID(), scale: 0.9).scale, 0.75)
        XCTAssertEqual(FloatingZone(host: UUID(), scale: 0.6).scale, 0.6)
    }

    func testAWindowThatCannotBeResizedStaysInTheMiddleOfTheZone() {
        XCTAssertEqual(FloatingZone.centred(CGSize(width: 100, height: 60), in: CGRect(x: 0, y: 0, width: 400, height: 300)),
                       CGRect(x: 150, y: 120, width: 100, height: 60))
    }

    func testALayoutKeepsItsFloatingZoneOnlyWhileItsHostIsAZoneOfTheScreen() {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = repository.addLayout(for: "A|d1")
        var strip = layout.strip
        strip.root = strip.root.splitting(strip.root.leafIDs[0], sideBySide: true, ratio: 0.5)
        repository.setStrip(strip, ofLayout: layout.id, key: "A|d1")
        let host = strip.root.leafIDs[1]

        repository.setFloatingZone(over: host, scale: 0.6, ofLayout: layout.id, key: "A|d1")
        let floating = repository.layout(id: layout.id, key: "A|d1")!.floatingZone
        XCTAssertEqual(floating?.host, host)
        XCTAssertEqual(floating?.scale, 0.6)
        XCTAssertEqual(repository.layout(id: layout.id, key: "A|d1")!.zoneIDs.last, floating?.id, "it is one of the layout's zones")

        repository.setFloatingZone(over: strip.root.leafIDs[0], scale: 0.4, ofLayout: layout.id, key: "A|d1")
        XCTAssertEqual(repository.layout(id: layout.id, key: "A|d1")!.floatingZone?.id, floating?.id, "moving it keeps its apps")

        repository.setFloatingZone(over: UUID(), scale: 0.5, ofLayout: layout.id, key: "A|d1")
        XCTAssertEqual(repository.layout(id: layout.id, key: "A|d1")!.floatingZone?.scale, 0.4, "a host that is no zone changes nothing")

        strip.root = .leaf(strip.root.leafIDs[1])   // the zone it floated over is gone
        repository.setStrip(strip, ofLayout: layout.id, key: "A|d1")
        XCTAssertNil(repository.layout(id: layout.id, key: "A|d1")!.floatingZone)
    }

    func testACopyFloatsOverTheCopyOfTheZoneAndNeverSharesItsIdentity() {
        let repository = LayoutRepository(store: MemoryStore())
        let layout = repository.addLayout(for: "A|d1")
        repository.setFloatingZone(over: layout.root.leafIDs[0], scale: 0.7, ofLayout: layout.id, key: "A|d1")
        let source = repository.layout(id: layout.id, key: "A|d1")!

        let copy = repository.duplicateLayout(id: layout.id, key: "A|d1", named: "Copy")!

        XCTAssertEqual(copy.floatingZone?.host, copy.root.leafIDs[0])
        XCTAssertEqual(copy.floatingZone?.scale, 0.7)
        XCTAssertNotEqual(copy.floatingZone?.id, source.floatingZone?.id)
    }

    func testAFileFromBeforeFloatingZonesHasNone() throws {
        let layout = NamedLayout(name: "Old", root: .leaf(UUID()))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as? [String: Any])
        object["floating"] = nil
        let decoded = try JSONDecoder().decode(NamedLayout.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.floating)
    }
}
