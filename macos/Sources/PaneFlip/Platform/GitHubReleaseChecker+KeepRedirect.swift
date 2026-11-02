import Foundation
import PaneFlipCore

extension GitHubReleaseChecker {
    /// Keeps the redirect itself: its destination is the answer.
    final class KeepRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
