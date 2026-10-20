# PaneFlip architecture

## Tests

- `Tests/PaneFlipCoreTests` (`swift test`): the pure domain.
- `Tests/PaneFlipTests` (`xcodebuild … test`): the app-layer rules (closed-window detection, restore order, zone
  hit-testing, the JSON store). They compile the services and their ports, not the app, and use fakes.
- `.github/workflows/release.yml` runs both on the tagged commit of main before it publishes a release (started by pushing the tag `v<version>`); no workflow runs for a pull request.

## Build layout

- `project.yml` → generates `PaneFlip.xcodeproj` (XcodeGen). It defines the **app target**: a real `.app` bundle
  (bundle id from `Config/Local.xcconfig`, `LSUIElement`, no sandbox, signed with the local certificate made by
  `scripts/setup-local-signing.sh` so the identity, and with it the Accessibility permission, is the same on every build).
- `Package.swift` holds only `PaneFlipCore` and its tests, so `swift test` needs no Xcode project.
- The app target depends on `PaneFlipCore` as a local package.

Two modules, dependencies point one way: `PaneFlip` (app) → `PaneFlipCore` (domain).

```
Sources/
├── PaneFlipCore/            Pure domain. Foundation + CoreGraphics only; unit-tested.
│   ├── Layout/              LayoutNode, SplitDivider, NamedLayout, LayoutPreset, Overflow, StripLayout, StripGeometry, Parking, ScreenLayouts, LayoutRepository, ZoneRemapper
│   ├── Stacks/              StackRecord, LayoutSlot, LayoutApp, StackMemory (what belongs where, in what order), TabNaming
│   ├── Settings/            AppSettings, SettingsValues, SettingsStorage (port), SnapTrigger, PillContent, PillPosition
│   ├── Updates/             AppVersion
│   └── Persistence/         DocumentStore (port)
└── PaneFlip/                The macOS app.
    ├── App/                 PaneFlipApp, AppContainer (composition root), AppLauncher (permission gate), MenuContent, MenuLayouts (layout switcher in the menu), MenuBarLabel
    ├── Permissions/         Permission, PermissionChecking (port) ← SystemPermissions, PermissionsModel,
    │                        PermissionsView, PermissionRow, PermissionsWindowController
    ├── Platform/            Ports, their value types and adapters:
    │                        WindowSystem ← AXWindowSystem (+ WindowRef),
    │                        WindowSnapshotting ← ScreenCaptureWindowSnapshots,
    │                        SlideStaging ← PanelSlideStage, ScrollStaging ← PanelScrollStage (both draw on StagePanels),
    │                        DisplayLinkMetronome (a function called at every refresh of a screen),
    │                        PointerMoveListening ← GlobalPointerMoves,
    │                        ScreenProviding (+ ScreenInfo, DockArea) ← CGSScreenProvider,
    │                        AppCatalog (+ AppInfo) ← WorkspaceAppCatalog,
    │                        BrandGlyphSource ← CDNBrandGlyphs,
    │                        ReleaseChecking (+ ReleaseInfo) ← GitHubReleaseChecker,
    │                        UpdateInstalling ← DiskImageUpdateInstaller (downloads the release disk image, checks its signature against the running app, swaps the app after it quits with `UpdateSwapScript`, which gives up if the app does not quit),
    │                        KeyShortcutListening ← EventTapKeyShortcut (four changeable shortcuts, `KeyChord` in Core: next/previous window of a zone, scroll toward the zones beyond the right/left edge; `KeyShortcut` is what a press asks for),
    │                        KeyStateProviding ← HardwareKeyState (+ SnapTrigger+KeyState),
    │                        LoginItemControlling ← SMAppServiceLoginItem,
    │                        ActivationPolicyControlling ← AppKitActivationPolicyController,
    │                        AppRelaunching ← WorkspaceAppRelauncher,
    │                        JSONFileStore, UserDefaultsSettingsStorage
    ├── Stacks/              ZoneStack, StackCoordinator, WindowRestorer, ClosedWindowMonitor, LayoutAppsService,
    │                        WindowAvailability, WindowSnapshot, ZoneCarousel, WindowGlide, WindowMover
    ├── Zones/               ZonePlanner, ZoneEngine, LayoutService; ports LayoutManaging, DisplayChangeHandling, LayoutAppsEditing (+ LayoutAppEntry, LayoutWindowEntry), ZonePresenting, ZoneRefreshing
    ├── Pill/                PillPresenter, PillPanel, PillMetrics, PillScrollStepper (scroll over the pill steps through the windows), IconFont, DoubleTapDetector
    ├── Snap/                SnapDragController, SnapZoneOverlay, SnapOverlayModel, SnapOverlayView
    ├── Editor/              EditorController, LayoutEditing (port), EditorModel, EditorView, EditorPanel,
    │                        EditorZone, SplitTarget
    └── Settings/            SettingsView (tabs), SettingsTab, SettingsNavigation, OrderingTarget, LayoutsPane, ZonesPane, StackingPane, ShortcutsPane, UpdatesPane, UpdatesModel, SettingRow,
                             SliderSettingRow, ScreenLayoutsSection, AppsPane, IgnoredAppsSection, LayoutCard, LayoutGapRow, LayoutMiniature, LayoutPresetSheet, KeyRecorder, GeneralPane, LaunchAtLoginModel,
                             FixedWindowTitle, TitleLockingView,
                             WindowPresenceReporter, WindowPresenceView,
                             PillContent+Title, PillPosition+Title, SnapTrigger+Title, AppLanguages
```

## File conventions

- **One type per file**, named after it. No exceptions: ports, their value types, adapters, panels, models and
  views each have their own file.
- An abstraction is never in the file of its implementation, so reading a consumer leads to the protocol,
  not to the concrete class.
- Folders group a layer's types by feature; an adapter sits next to the port it implements.
- Core exposes only what the app needs; helpers such as `LayoutNode.build` stay internal.

## Responsibilities

| Type | Single job |
|---|---|
| `LayoutRepository` | Store layouts per display (shared by its desktops) and which one each desktop uses. Knows nothing about windows. |
| `StripLayout` / `StripGeometry` | A screen's layout with the zones (`Overflow`) beyond its left and right edges as one strip; where each zone stands for a scroll offset, how far the screen may scroll and where a scroll comes to rest. Pure arithmetic. `Parking` tells where a window waits when its zone is out of sight (one pixel on the display, at a side with no display beside it). |
| `StripScroller` / `StripViewport` | A scroll (the shortcut or `EdgeScroller`) moves the screen along its strip: pictures of the windows in front glide (the render server moves them, so they glide whatever the apps or the machine do) while the real windows wait at the display's edge; the pictures glide on to the nearest rest position, the windows are put where they belong, and the pictures fade away. A press while a scroll runs gives it a new aim (the next rest position, or back). Pictures taken in earlier scrolls stand in at once. The viewport remembers each screen's offset for `ZonePlanner`. |
| `EdgeScroller` | Rest the pointer at the left or right edge of a screen for a second and the zones beyond that edge scroll into view; the pointer must leave the edge to scroll again. |
| `WindowMover` | Writes the positions of many windows off the main thread, one app at a time, latest wanted place only. |
| `StackMemory` | Remember which app belongs to which zone, in the user's order. Knows nothing about windows. |
| `StackCoordinator` | Keep live stacks and memory in step with real windows (snap, select, release). |
| `ZoneCarousel` | Slide the chosen window of a zone in beside the one in front: both are photographed (Screen Recording), the pictures slide inside the zone while the real windows swap underneath, so nothing shows outside the zone. A press in the same direction while it runs carries the slide on to the next window (one more picture, the same spring). |
| `WindowGlide` | Move a window the user just dropped from where it is to its zone in a short ease-out glide (steps follow the clock, off the main thread, the last one exact; no glide with Reduce Motion). |
| `UpdatesModel` | Ask, when the user presses the button, whether a newer release exists and install it when the user asks. Nothing is checked on its own. |
| `WindowRestorer` | Put running windows in the zone their app belongs in: remembered ones in their slots, every other window of the app next to them. |
| `ClosedWindowMonitor` / `WindowAvailability` | Notice closed, hidden or minimized windows. |
| `ZonePlanner` | Compute which zones exist and where, for each screen's scroll: in view, or waiting beyond a display's edge. |
| `ZoneEngine` | Re-layout on desktop/display changes and run housekeeping. |
| `LayoutService` | Apply layout edits and carry their consequences to windows and memory. |
| `PillPresenter` | Own pill panels and decide when each is visible. |
| `PillPanel` | The pill: the system's segmented control, one segment per window, and the toolbar buttons that open the apps' order in Settings and hide it. |
| `IconFont` | Single-colour glyphs for segments (system glyph table, brand glyphs, or the app icon's shape). |
| `CDNBrandGlyphs` | Fetch a brand glyph from a public icon set once and keep it on disk; asks nothing while the setting is off. |
| `LayoutAppsService` | Edits which app belongs in which zone of a layout, and in what pill order; lets the restorer place the windows. |
| `SnapDragController` | Window drag + trigger key → snap. |
| `AppContainer` | Build everything once and wire it. No globals anywhere else. |

## Principles in practice

- **Single responsibility:** the old 500-line `WindowManager` is split as above.
- **Dependency inversion:** services depend on `WindowSystem`, `ScreenProviding`, `AppCatalog`, `DocumentStore`,
  `SettingsStorage`, `KeyStateProviding`, `BrandGlyphSource` protocols; only `AppContainer` names the concrete adapters.
- **Interface segregation:** UI sees `LayoutManaging`, `LayoutEditing` and `LayoutAppsEditing`, not the services behind them;
  collaborators that only need a re-layout see `ZoneRefreshing`.
- **Open/closed:** a new presenter conforms to `ZonePresenting` and is added to the engine; a different window
  backend is another `WindowSystem`.
- **Encapsulation:** domain types expose intent (`remap`, `unbind`, `forget`, `assign`, `moveSlot`), not their arrays.
- **Composition over inheritance:** no class hierarchies; behaviour is assembled from small collaborators.

## Stage Manager

With Stage Manager on, the window server decides which windows are shown, so the app does one thing: a window dropped into a
zone is sized and placed by it (with the glide). Everything else is off: `StackCoordinator.placementOnly` makes `snap` return
after the placement and stops `unsnap`, the shortcut, title and focus following and re-framing of held windows; the pill is
hidden, and `ClosedWindowMonitor` and `WindowRestorer` do nothing. The settings, layouts and remembered apps are the same in
both modes, and nothing remembered is read or changed while it is on.
