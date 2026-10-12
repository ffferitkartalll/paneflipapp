import AppKit
import XCTest

/// Answers every request itself, so no test touches the network or the real icon cache.
private final class StubHost: URLProtocol {
    nonisolated(unsafe) static var requests = 0
    nonisolated(unsafe) static var status: Int?   // nil: the request fails

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        Self.requests += 1
        guard let status = Self.status else { return client!.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client!.urlProtocolDidFinishLoading(self)
    }
}

final class CDNBrandGlyphsFetchTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        StubHost.requests = 0
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    private func glyphs(enabled: Bool = true, retryAfter: TimeInterval = 300) -> CDNBrandGlyphs {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubHost.self]
        return CDNBrandGlyphs(session: URLSession(configuration: configuration), folder: folder, retryAfter: retryAfter,
                              isEnabled: { enabled })
    }

    private func wait(_ seconds: TimeInterval) {
        let done = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// Polls until `condition` holds (or the time is up), so a slow machine only makes the test longer.
    private func wait(until condition: () -> Bool, timeout: TimeInterval = 5) {
        let end = Date().addingTimeInterval(timeout)
        while !condition(), Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    }

    func testNothingIsRequestedWhileTheSwitchIsOff() {
        StubHost.status = 200
        let source = glyphs(enabled: false)
        _ = source.glyph(forApp: "Brand")
        wait(0.3)
        withExtendedLifetime(source) {}
        XCTAssertEqual(StubHost.requests, 0)
    }

    func testAMissingIconIsAskedOnlyOnce() {
        StubHost.status = 404
        let source = glyphs()
        _ = source.glyph(forApp: "Brand")
        wait(until: { StubHost.requests == 1 })
        wait(0.2)   // the answer is handled on the main queue; only then is the miss remembered
        _ = source.glyph(forApp: "Brand")
        wait(0.3)
        XCTAssertEqual(StubHost.requests, 1)
    }

    func testAFailedRequestIsTriedAgainButNotForever() {
        StubHost.status = nil
        let source = glyphs(retryAfter: 0.05)
        _ = source.glyph(forApp: "Brand")
        wait(until: { StubHost.requests >= 3 })
        wait(0.3)   // and no fourth one
        withExtendedLifetime(source) {}
        XCTAssertEqual(StubHost.requests, 3)
    }

    func testFlippingTheSwitchChangesTheVersion() {
        var enabled = true
        let source = CDNBrandGlyphs(folder: folder, isEnabled: { enabled })
        let before = source.version
        enabled = false
        XCTAssertNotEqual(source.version, before)
    }
}
