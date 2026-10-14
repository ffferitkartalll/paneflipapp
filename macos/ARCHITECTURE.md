# PaneFlip architecture

## Tests

- `Tests/PaneFlipCoreTests` (`swift test`): the pure domain.
- `Tests/PaneFlipTests` (`xcodebuild … test`): the app-layer rules (closed-window detection, restore order, zone
  hit-testing, the JSON store). They compile the services and their ports, not the app, and use fakes.
- `.github/workflows/test.yml` runs both on every pull request.

## Build layout

- `project.yml` → generates `PaneFlip.xcodeproj` (XcodeGen). It defines the **app target**: a real `.app` bundle
  (bundle id `dev.ffferitkartalll.paneflip`, `LSUIElement`, no sandbox, signed with the local certificate made by
  `scripts/setup-local-signing.sh` so the identity, and with it the Accessibility permission, is the same on every build).
- `Package.swift` holds only `PaneFlipCore` and its tests, so `swift test` needs no Xcode project.
- The app target depends on `PaneFlipCore` as a local package.

Two modules, dependencies point one way: `PaneFlip` (app) → `PaneFlipCore` (domain).

```
Sources/
├── PaneFlipCore/            Pure domain. Foundation + CoreGraphics only; unit-tested.
│   ├── Layout/              LayoutNode, SplitDivider, NamedLayout, ScreenLayouts, LayoutRepository, ZoneRemapper
│   ├── Stacks/              StackRecord, LayoutSlot, LayoutApp, StackMemory (what belongs where, in what order), TabNaming
│   ├── Settings/            AppSettings, SettingsValues, SettingsStorage (port), SnapTrigger, PillContent
│   └── Persistence/         DocumentStore (port)
└── PaneFlip/                The macOS app.
    ├── App/                 PaneFlipApp, AppContainer (composition root), AppLauncher (permission gate), MenuContent
    ├── Permissions/         Permission, PermissionChecking (port) ← SystemPermissions, PermissionsModel,
    │                        PermissionsView, PermissionRow, PermissionsWindowController
    ├── Platform/            Ports, their value types and adapters:
    │                        WindowSystem ← AXWindowSystem (+ WindowRef),
    │                        ScreenProviding (+ ScreenInfo) ← CGSScreenProvider,
    │                        AppCatalog (+ AppInfo) ← WorkspaceAppCatalog,
    │                        BrandGlyphSource ← CDNBrandGlyphs,
    │                        KeyStateProviding ← HardwareKeyState (+ SnapTrigger+KeyState),
    │                        LoginItemControlling ← SMAppServiceLoginItem,
    │                        ActivationPolicyControlling ← AppKitActivationPolicyController,
    │                        JSONFileStore, UserDefaultsSettingsStorage
    ├── Stacks/              ZoneStack, StackCoordinator, WindowRestorer, ClosedWindowMonitor, LayoutAppsService,
    │                        WindowAvailability, WindowSnapshot
    ├── Zones/               ZonePlanner, ZoneEngine, LayoutService; ports LayoutManaging, LayoutAppsEditing (+ LayoutAppEntry, LayoutWindowEntry), ZonePresenting, ZoneRefreshing
    ├── Pill/                PillPresenter, PillPanel, PillMetrics, IconFont, DoubleTapDetector
    ├── Snap/                SnapDragController, SnapZoneOverlay, SnapOverlayModel, SnapOverlayView
    ├── Editor/              EditorController, LayoutEditing (port), EditorModel, EditorView, EditorPanel,
    │                        EditorZone, SplitTarget
    └── Settings/            SettingsView (tabs), LayoutsPane, StackingPane, ShortcutsPane, SettingRow,
                             SliderSettingRow, ScreenLayoutsSection, LayoutCard, KeyRecorder, GeneralPane, LaunchAtLoginModel,
                             FixedWindowTitle, TitleLockingView,
                             WindowPresenceReporter, WindowPresenceView,
                             PillContent+Title, SnapTrigger+Title, AppLanguages
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
| `LayoutRepository` | Store layouts per screen. Knows nothing about windows. |
| `StackMemory` | Remember which app belongs to which zone, in the user's order. Knows nothing about windows. |
| `StackCoordinator` | Keep live stacks and memory in step with real windows (snap, select, release). |
| `WindowRestorer` | Put running windows in the zone their app belongs in: remembered ones in their slots, every other window of the app next to them. |
| `ClosedWindowMonitor` / `WindowAvailability` | Notice closed, hidden or minimized windows. |
| `ZonePlanner` | Compute which zones are visible and where. |
| `ZoneEngine` | Re-layout on desktop/display changes and run housekeeping. |
| `LayoutService` | Apply layout edits and carry their consequences to windows and memory. |
| `PillPresenter` | Own pill panels and decide when each is visible. |
| `PillPanel` | The pill: the system's segmented control, one segment per window, and the toolbar button that hides it. |
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
