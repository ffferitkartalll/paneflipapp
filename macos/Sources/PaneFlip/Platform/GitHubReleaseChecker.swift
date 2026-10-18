import Foundation
import PaneFlipCore

/// Finds the newest release on GitHub, only when the user asks. It reads where `releases/latest` points instead of
/// asking the API, which allows few requests an hour from one address (and many users share one).
struct GitHubReleaseChecker: ReleaseChecking {
    enum Failure: Error { case unreadable }

    /// Keeps the redirect itself: its destination is the answer.
    private final class KeepRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    let repository: String
    var session = URLSession.shared

    func latestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: URL(string: "https://github.com/\(repository)/releases/latest")!)
        request.timeoutInterval = 15
        let (_, response) = try await session.data(for: request, delegate: KeepRedirect())
        guard let http = response as? HTTPURLResponse, (300..<400).contains(http.statusCode),
              let location = http.value(forHTTPHeaderField: "Location"), let page = URL(string: location, relativeTo: request.url)?.absoluteURL,
              page.pathComponents.contains("tag"), let version = AppVersion(page.lastPathComponent) else { throw Failure.unreadable }
        return ReleaseInfo(version: version, page: page)
    }
}
