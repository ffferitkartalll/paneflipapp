# Contributing

Thank you for helping. A change goes through the same steps for everyone, so that every change has a reason on
record and has been tried before it lands.

## The steps

1. **Open an issue first** that says what is wrong or what you want (a bug, an enhancement, documentation), so it
   can be agreed before work is spent. Use neutral wording and no screenshots of private data.
2. **Branch** from `main` and name it after the issue (`issue-<number>`; several issues in one pull request:
   `issue-<number>-<number>`).
3. **Make the change small** and keep to the rules below. Add or update tests with it.
4. **Open a pull request** to `main` that says `Closes #<number>` for each issue. The Tests workflow must pass
   (`swift test` for the domain module, `xcodebuild … test` for the app layer).
5. The maintainer tries the change on their Mac, then merges it.

Pull requests from forks run the tests only after the maintainer approves the run.

## Rules of the code

Read [`macos/ARCHITECTURE.md`](macos/ARCHITECTURE.md) first: it is the map. In short:

- Two modules, one direction: `PaneFlip` (the app) depends on `PaneFlipCore` (the domain), never the reverse.
  `PaneFlipCore` imports only Foundation, CoreGraphics and Observation.
- One type per file, named after the type. Anything that touches the system is a protocol in `Platform/` with
  the adapter in its own file; dependencies come through initializers and are wired only in `AppContainer`.
- No global state and no singletons.
- Every text the user sees is in `Localizable.xcstrings` (English), and the catalog holds exactly the keys the
  build extracts. Do not edit other languages by hand there; they come from Crowdin.
- Every call into another app's windows is cheap and bounded; timers do not rebuild system window lists when
  nothing changed.
- No names of other applications in code, comments, tests or docs (the bundle identifiers in `AppGlyphs.json` are
  data and the exception).
- Commit messages say what and why in plain words; they carry no tool or AI attribution lines.

## Set-up

See the macOS section of the [README](README.md): your own bundle identifier in `macos/Config/Local.xcconfig`, a
local signing certificate, `xcodegen generate`.

The Xcode project is generated from `macos/project.yml`; never edit `PaneFlip.xcodeproj` by hand.
