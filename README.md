# PaneFlip

[![Crowdin](https://badges.crowdin.net/paneflipapp/localized.svg)](https://crowdin.com/project/paneflipapp)

Split your displays and desktops into zones, drop apps into them, and switch between the apps of a zone with a
small glass pill. It is a native macOS menu-bar app.

## macOS

Requires macOS 27, Xcode 27 (Swift 6.4) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
cd macos
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then set your own bundle identifier in it
./scripts/setup-local-signing.sh   # once per Mac: a local signing certificate (see below)
xcodegen generate                  # creates PaneFlip.xcodeproj from project.yml
open PaneFlip.xcodeproj            # run the PaneFlip scheme on "My Mac"
```

**Use your own bundle identifier.** `Config/Local.xcconfig` (ignored by git) holds `PANEFLIP_BUNDLE_ID`; the
example file has a placeholder. macOS ties the permissions the app is given, and its saved settings, to the
bundle identifier, so choose one that belongs to you (reverse-DNS, for example `com.yourname.paneflip`) and keep
using it.

**Why the signing step:** macOS ties the Accessibility permission to the app's code signature. Ad-hoc signed
debug builds get a new signature on every build, so the permission would be asked for again each time. The script
creates a self-signed certificate in your login keychain (macOS asks for your password once to trust it); every
build is then signed with it and the permission is kept. With an Apple developer account, set `DEVELOPMENT_TEAM`
and your identity in `project.yml` instead.

If you delete and recreate the certificate, quit and reopen Xcode afterwards: a running Xcode remembers the
old certificate and fails with `no identity found` until it is restarted.

The domain module and its tests build without Xcode: `cd macos && swift test`.

The app is an agent app (menu bar only, no Dock icon). The first launch asks for the Accessibility permission.

- [`macos/ARCHITECTURE.md`](macos/ARCHITECTURE.md): layers, folders, responsibilities.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): how changes are made.

## Good to know

- **Not for the Mac App Store.** To move other apps' windows PaneFlip needs the Accessibility permission and runs
  without the App Sandbox, and it uses some undocumented system interfaces (private CoreGraphics Services calls
  for desktops and the cursor, private AppKit selectors for the pill's look). A system update can change them; the
  app then falls back to a plainer look instead of failing.
- **Brand icons.** When an app has no system symbol, PaneFlip can fetch a one-colour brand icon from the
  [Simple Icons](https://simpleicons.org) set through the jsDelivr CDN (`Settings ▸ Stacking ▸ Fetch brand
  icons`, on by default; the names of the apps in your zones are sent to the host, nothing else). Trademarks and
  logos belong to their owners. Turn it off and nothing is looked up.
- **No data leaves your Mac** otherwise: layouts, memory and settings are local files and preferences.

## Translations

The app's texts are in `macos/Sources/PaneFlip/Resources/Localizable.xcstrings`, and a language is added by
translating that catalog: no code changes. Translations are made in the public Crowdin project
**[PaneFlip on Crowdin](https://crowdin.com/project/paneflipapp)**: pick your language (or ask for a new one),
translate there, and Crowdin sends a pull request with the result. You can also edit the catalog directly in a
pull request. A language appears in `Settings ▸ General ▸ Language` as soon as the catalog has it.

## Contributing and security

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Report a security problem as
described in [SECURITY.md](SECURITY.md), not in a public issue.

## Platforms

One repository, one folder per platform.

| Platform | Folder | Status |
|---|---|---|
| macOS | [`macos/`](macos/) | Working |
| Windows | `windows/` | Not started |
| Linux | `linux/` | Not started |

Each platform is a self-contained project with its own build, tests and architecture notes, and uses the
platform's native UI and window APIs. Start from the platform's own README or `ARCHITECTURE.md`.

## Adding a platform

Create a new top-level folder (`windows/`, `linux/`, …). Keep platform code inside it; do not share source files
across platforms. Product behaviour that should stay identical (how zones, stacks and the pill behave) is the
reference in `macos/ARCHITECTURE.md` and the unit tests of `macos/Sources/PaneFlipCore`.

## License

[MIT](LICENSE).
