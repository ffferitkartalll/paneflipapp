# PaneFlip (macOS) — working rules

Paths in this file are relative to `macos/`. Run all `swift` commands from there.

PaneFlip is a native macOS menu-bar app that splits displays/desktops into zones and stacks apps in them.
Read `ARCHITECTURE.md` before changing anything: it is the map. These rules are mandatory for every change.

## Build and verify

- The Xcode project is generated: after adding, moving or removing a file or changing build settings, run
  `xcodegen generate` in `macos/` (settings live in `project.yml`, never edit the `.xcodeproj` by hand).
- Signing uses a local certificate (`scripts/setup-local-signing.sh`, once per Mac). Never switch
  `CODE_SIGN_IDENTITY` back to ad-hoc `"-"`: it changes every build and macOS re-asks for the permission.
- Verify with `xcodebuild -project PaneFlip.xcodeproj -scheme PaneFlip -destination 'platform=macOS' build`
  and `swift test`. Both must pass before finishing a change.
- Debug builds only. Do not add packaging/release scripts; the owner runs the app from Xcode on "My Mac".
- Add or update tests for every change in `PaneFlipCore`.
- Keep `ARCHITECTURE.md` in step when a type is added, moved or removed.

## Architecture (do not bend it)

1. **Two modules, one direction.** `PaneFlip` (app) depends on `PaneFlipCore` (domain), never the reverse.
   Core imports only Foundation/CoreGraphics/Observation — no AppKit, no Accessibility, no SwiftUI.
2. **One type per file**, named after the type, no exceptions: ports, value types, adapters, panels, models, views.
   Extensions get their own file named `Type+Topic.swift`. Tests: one test case class per file.
3. **Ports and adapters.** Anything that touches the system (windows, screens, apps, keys, disk, UserDefaults)
   is a protocol in `Platform/` (or a Core port); the concrete adapter is a separate file. Services depend on
   the protocol only. A protocol never shares a file with its implementation.
4. **No singletons, no globals.** Dependencies come through initializers. `AppContainer` is the only place
   that creates concrete objects and wires them. Do not add `static let shared`.
5. **Single responsibility.** A class has one reason to change. If a type needs "and" to describe it, split it.
   Coordinators coordinate; they do not compute (put pure logic in Core value types or small structs).
6. **Interface segregation.** UI depends on narrow protocols (`LayoutManaging`, `LayoutEditing`), not on services.
7. **Encapsulation.** Domain types expose intent (`remap`, `unbind`, `applyOrder`), not mutable arrays. Prefer
   `private`; widen access only when another file needs it. `public` is for what the app target uses from Core.
8. **Composition over inheritance.** Subclass only to satisfy a framework (`NSPanel`); no hierarchies of our own.
9. **Value types for data.** Layout trees, records, settings values are structs/enums with value semantics.
   Observable state classes use `@Observable`; mark non-UI properties `@ObservationIgnored`.

## User-facing text

- The UI is English. Strings live in `Sources/PaneFlip/Resources/Localizable.xcstrings`; after adding or removing
  a string, build and take the keys the compiler extracted (`*.stringsdata` under the build's `OBJROOT`): the
  catalog must contain exactly those keys.
- **SwiftUI literals** (`Text("…")`, `Label`, `Button`, `Toggle`, `.help`…) need nothing special. Reusable views
  take `LocalizedStringKey`, never `String`, for titles and descriptions.
- **Plain `String` text** uses `String(localized: "…")`. Numbers, sizes and names that come from the system or
  the user use `Text(verbatim:)`.
- **No user-facing text in `PaneFlipCore`.** Core holds stable identifiers; the app maps them to text
  (`PillContent+Title`, `SnapTrigger+Title`). Default names are made in the app (`LayoutService.addLayout`).
- Use one English word per concept (Layout, Zone, Stack, Pill).

## Where new code goes

| You are adding… | It goes in… |
|---|---|
| Layout or zone math, anything testable without windows | `PaneFlipCore/Layout` or `PaneFlipCore/Stacks` |
| A user setting | `PaneFlipCore/Settings` (`SettingsValues` + `AppSettings`) + storage key in `UserDefaultsSettingsStorage` + a `SettingRow` in the fitting tab pane (`GeneralPane`, `LayoutsPane`, `PlacementPane`, `StackingPane`) |
| A new way to read or move windows/screens/apps/keys | a protocol in `Platform/` + adapter file next to it |
| Behaviour that keeps windows and memory in step | `Stacks/` (`StackCoordinator` or a new focused collaborator) |
| Reacting to desktop/display changes, periodic work | `Zones/` (`ZoneEngine` or a new collaborator it owns) |
| Anything drawn on the pill | `Pill/` (geometry in `PillMetrics`, state in `ZoneStack`, visibility in `PillPresenter`) |
| Window-drag behaviour | `Snap/` |
| Layout editor behaviour | `Editor/` (state in `EditorModel`, drawing in `EditorView`) |
| A new required system permission | a case in `Permissions/Permission`; the screen, polling and launch gate pick it up |
| A new user-facing string | the code that shows it + its key in `Resources/Localizable.xcstrings` |
| A new object | construct and wire it in `AppContainer` only |

## Product decisions already made

- Targets the latest macOS (27); use Liquid Glass components.
- No global keyboard shortcuts. Windows are added by dragging with the snap trigger held (default Left Shift,
  user-configurable). The pill is hidden until the pointer is exactly over it or the stack changed.
- Closed, hidden and minimized windows leave their zone at once; their memory slot stays so they return.
- PaneFlip is a menu-bar-only app, except while one of its own windows (Settings, the permission screen) is
  open: then it is a regular app (Dock icon, its name in the menu bar). Any new window of ours must report its
  open/close to `ActivationPolicyControlling`.
- Do not change user-visible behaviour while refactoring; behaviour changes are made on request only.
