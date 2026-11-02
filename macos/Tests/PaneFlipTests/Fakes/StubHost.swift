import AppKit
import XCTest

/// Answers every request itself, so no test touches the network or the real icon cache.
final class StubHost: URLProtocol {
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
