import Foundation

/// A running application, as the app needs to see it.
struct AppInfo {
    let pid: pid_t
    let bundleID: String
    let name: String
}
