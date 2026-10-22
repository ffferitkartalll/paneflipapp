import Foundation

/// The shell that outlives the app while it is replaced: it waits for the app to quit, puts the new app in its place (the old one
/// comes back if that fails, and the new copy does not stay behind) and opens it. It gives up when the app does not quit.
enum UpdateSwapScript {
    /// Arguments of the script: the installed app, the new app next to it, the program that opens an app, how many 0.2 s waits for
    /// the app to quit it allows.
    static let text = """
    waited=0
    while kill -0 "$1" 2>/dev/null; do
      sleep 0.2
      waited=$((waited + 1))
      if [ "$waited" -gt "$5" ]; then rm -rf "$3"; exit 1; fi
    done
    if mv "$2" "$2.old"; then
      if mv "$3" "$2"; then rm -rf "$2.old"; else mv "$2.old" "$2"; fi
    fi
    rm -rf "$3"
    "$4" "$2"
    """

    /// Starts the script for the running app; it carries on after the app has quit.
    static func start(app: URL, staged: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = arguments(waitingFor: ProcessInfo.processInfo.processIdentifier, app: app, staged: staged, open: "/usr/bin/open", patience: 150)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func arguments(waitingFor pid: Int32, app: URL, staged: URL, open: String, patience: Int) -> [String] {
        ["-c", text, "sh", String(pid), app.path, staged.path, open, String(patience)]
    }
}
