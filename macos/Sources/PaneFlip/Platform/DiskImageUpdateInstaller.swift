import AppKit
import Security

/// Installs a release from its disk image on GitHub: downloads it, takes the app out of it, checks that it is signed by the same
/// certificate as the running app, and swaps the two once the running one has quit.
final class DiskImageUpdateInstaller: UpdateInstalling {
    enum Failure: Error { case notWritable, download, mount, missingApp, notSignedByUs }

    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func install(_ release: ReleaseInfo) async throws {
        let app = Bundle.main.bundleURL
        let folder = app.deletingLastPathComponent()
        let files = FileManager.default
        guard files.isWritableFile(atPath: folder.path) else { throw Failure.notWritable }

        let work = files.temporaryDirectory.appendingPathComponent("PaneFlipUpdate-\(UUID().uuidString)")
        try files.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: work) }

        let (downloaded, response) = try await session.download(from: release.diskImage)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.download }
        let image = work.appendingPathComponent("update.dmg")
        try files.moveItem(at: downloaded, to: image)

        let mount = work.appendingPathComponent("mount")
        guard try Self.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noverify", "-mountpoint", mount.path, image.path]) else {
            throw Failure.mount
        }
        defer { _ = try? Self.run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }
        let source = mount.appendingPathComponent("PaneFlip.app")
        guard files.fileExists(atPath: source.path) else { throw Failure.missingApp }

        // Beside the installed app, so the swap is a rename on one volume.
        let staged = folder.appendingPathComponent(".PaneFlip-update.app")
        try? files.removeItem(at: staged)
        guard try Self.run("/usr/bin/ditto", [source.path, staged.path]) else { throw Failure.missingApp }
        guard Self.isSignedLikeThisApp(staged) else {
            try? files.removeItem(at: staged)
            throw Failure.notSignedByUs
        }
        try Self.swapAfterQuit(app: app, staged: staged)
        await MainActor.run { NSApp.terminate(nil) }
    }

    /// True when the app at `url` satisfies the requirement this running app was signed with (same identifier, same certificate).
    private static func isSignedLikeThisApp(_ url: URL) -> Bool {
        var running: SecCode?, runningStatic: SecStaticCode?, requirement: SecRequirement?, candidate: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &runningStatic) == errSecSuccess, let runningStatic,
              SecCodeCopyDesignatedRequirement(runningStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(url as CFURL, [], &candidate) == errSecSuccess, let candidate else { return false }
        return SecStaticCodeCheckValidity(candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate), requirement) == errSecSuccess
    }

    /// A shell that outlives this app: waits for it to quit, puts the new app in its place (the old one comes back if that fails)
    /// and opens it.
    private static func swapAfterQuit(app: URL, staged: URL) throws {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        if mv "$1" "$1.old"; then
          if mv "$2" "$1"; then rm -rf "$1.old"; else mv "$1.old" "$1"; fi
        fi
        open "$1"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", app.path, staged.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    /// Runs a tool and says whether it succeeded.
    private static func run(_ tool: String, _ arguments: [String]) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
