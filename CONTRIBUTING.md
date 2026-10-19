# Contributing

Thank you for helping. A change goes through the same steps for everyone, so that every change has a reason on
record and has been tried before it lands.

## The steps

1. **Open an issue first** that says what is wrong or what you want (a bug, an enhancement, documentation), so it
   can be agreed before work is spent. Use neutral wording and no screenshots of private data.
2. **Branch** from `main` and name it after the issue (`issue-<number>`; several issues in one pull request:
   `issue-<number>-<number>`).
3. **Make the change small** and keep to the rules below. Add or update tests with it.
4. **Open a pull request** to `main` that says `Closes #<number>` for each issue. Run `swift test` (domain
   module) and `xcodebuild … test` (app layer) yourself; the Tests workflow runs only for a pull request that
   carries the `release` label (see Releases below).
5. The maintainer tries the change on their Mac, then turns on auto-merge for the pull request: it is squashed into
   `main` as soon as the required checks (`changes`, `macos`) have passed. They are skipped, and so count as passed,
   unless the pull request carries the `release` label; a release pull request is merged only if the Tests workflow
   passes, and never if it fails.

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

## Releases

A release is published only when the maintainer says so: the pull request gets the `release` label and raises
`MARKETING_VERSION` in `macos/project.yml`. With the label, the Tests workflow runs on the pull request, and once it is
merged the Release workflow builds the app, signs it with the release certificate, and publishes the `.dmg` as release
`v<version>` with notes made from the merged pull requests. No other pull request or merge publishes anything, and a
version that has a release already stops the workflow. The workflow needs the repository secrets `RELEASE_CERT_P12`
(base64 of a `.p12` with a code-signing identity named `PaneFlip Release`) and `RELEASE_CERT_PASSWORD`, and the variable
`PANEFLIP_BUNDLE_ID`. Last, the workflow sets `version` in `casks/paneflipapp.rb` of
[`homebrew-tap`](https://github.com/ffferitkartalll/homebrew-tap) (the Homebrew cask) to the new version; for that it needs the
secret `TAP_TOKEN` (a fine-grained token with contents write on that repository only). Keep the same certificate for every release: it is the app's identity, and macOS ties the
permissions it gave the app to it.
