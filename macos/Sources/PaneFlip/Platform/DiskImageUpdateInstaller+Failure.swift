import AppKit
import Security

extension DiskImageUpdateInstaller {
    enum Failure: Error { case notWritable, download, mount, missingApp, notSignedByUs }
}
