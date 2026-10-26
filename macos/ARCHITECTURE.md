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
│   ├── Layout/              LayoutNode, SplitDivider, NamedLayout, NamedLayout+File (a layout as a file: export, import), LayoutPreset, SplitSnap (the proportions a split line sticks to: 1/4, 1/3, 1/2, 2/3, 3/4), Overflow, StripLayout, StripGeometry, PagedScroll (a swipe or a wheel notch as a step to the next screen), Parking, ScreenLayouts, LayoutRepository, ZoneGlyph (a screen's zones, those beyond its edges too, drawn small in a row), FloatingZone (a zone that floats over the middle of another one: its size, where it stands, how a window that cannot be resized is centred in it), ZoneDirection, ZoneNeighbour (the zone beside a zone in a direction), ZoneRemapper
│   ├── Stacks/              StackRecord, LayoutSlot, LayoutApp, StackMemory (what belongs where, in what order), TabNaming, ScrubGesture (a swipe through a zone's windows: how far, how fast, what it chooses), FingerSwipe (the fingers on the trackpad as a swipe with three or four: when it begins and ends), AxisLock (a swipe is horizontal or not, decided in its first points)
│   ├── Snap/                ShakeDetector (a shake of the pointer from side to side: it switches the snap on during a window drag)
│   ├── Settings/            AppSettings, SettingsValues, SettingsStorage (port), SnapTrigger, PillContent, PillPosition, TrackpadMethod
│   ├── Updates/             AppVersion
│   └── Persistence/         DocumentStore (port)
└── PaneFlip/                The macOS app.
    ├── App/                 PaneFlipApp, AppContainer (composition root), AppLauncher (permission gate), MenuContent, MenuLayouts (layout switcher in the menu), MenuBarLabel
    ├── Permissions/         Permission, PermissionChecking (port) ← SystemPermissions, PermissionsModel,
    │                        PermissionsView, PermissionRow, PermissionsWindowController
    ├── Platform/            Ports, their value types and adapters:
    │                        WindowSystem ← AXWindowSystem (+ WindowRef),
    │                        WindowSnapshotting ← ScreenCaptureWindowSnapshots,
    │                        SlideStaging ← PanelSlideStage, ScrollStaging ← PanelScrollStage (both draw on StagePanels), ScrollPreviewing ← PanelScrollPreview (the map of the strip shown while the layout scrolls),
    │                        FloatStaging ← PanelFloatStage (+ FloatSlide: the picture of a floating zone's window going out, with the spring of the slides inside a zone (`SlideSpring`), from behind the window that took the focus, in front of the others; the window that comes is the real one, gliding in with the same spring),
    │                        WindowPictureLayer (a window's picture as a layer: rounded like the window, with the shadow of a window; every stage uses it),
    │                        DisplayLinkMetronome (a function called at every refresh of a screen),
    │                        PointerMoveListening ← GlobalPointerMoves,
    │                        ScreenProviding (+ ScreenInfo, DockArea) ← CGSScreenProvider,
    │                        AppCatalog (+ AppInfo) ← WorkspaceAppCatalog,
    │                        BrandGlyphSource ← CDNBrandGlyphs,
    │                        ReleaseChecking (+ ReleaseInfo) ← GitHubReleaseChecker,
    │                        UpdateInstalling ← DiskImageUpdateInstaller (downloads the release disk image, checks its signature against the running app, swaps the app after it quits with `UpdateSwapScript`, which gives up if the app does not quit),
    │                        ScrollSwitchListening ← EventTapScrollSwitch (the mouse wheel with the keys held steps through a zone's windows or the layout, and so do two fingers with the keys held when the `TrackpadMethod` setting is `keysAndTwoFingers`) and MultitouchSwipes (when it is `threeAndFourFingers`: three fingers on the trackpad lead the slide through a zone's windows, four the layout toward the zones beyond the edges; read through the system's private multitouch framework, loaded at start; `ScrollSwitchEvent`, `ScrollSwitchTarget`) and MouseButtonSwipes (the mouse's wheel button held and moved to the side leads the windows of the zone under the pointer; the pointer stays and shows a hand, which only holds while this app is the active one, so it is made active meanwhile; a click that never moves is posted again),
    │                        KeyShortcutListening ← EventTapKeyShortcut (four changeable shortcuts, `KeyChord` in Core: next/previous window of a zone, scroll toward the zones beyond the right/left edge; `KeyShortcut` is what a press asks for),
    │                        KeyStateProviding ← HardwareKeyState (+ SnapTrigger+KeyState),
    │                        LoginItemControlling ← SMAppServiceLoginItem,
    │                        ActivationPolicyControlling ← AppKitActivationPolicyController,
    │                        AppRelaunching ← WorkspaceAppRelauncher,
    │                        JSONFileStore, UserDefaultsSettingsStorage
    ├── Stacks/              ZoneStack, StackCoordinator, WindowRestorer, ClosedWindowMonitor, LayoutAppsService,
    │                        WindowAvailability, WindowSnapshot, ZoneCarousel, WindowGlide, WindowMover
    ├── Zones/               ZonePlanner, ZoneFlash (outlines the zone the focus went to), ZoneEngine, StripPreview (the map of a strip: the layout editor and the scroll show it), ScrollSwitchHandler (what the scroll with the keys held asks for), LayoutService; ports LayoutManaging, DisplayChangeHandling, LayoutAppsEditing (+ LayoutAppEntry, LayoutWindowEntry), ZonePresenting, ZoneRefreshing
    ├── Pill/                PillPresenter, PillPanel, PillMetrics, PillScrolling, PillScrollRouter (scrolling over the pill: two fingers lead the zone's windows, a wheel steps through them), IconFont, DoubleTapDetector
    ├── Island/              MenuBarIsland (a ZonePresenting: the island in the menu bar, never taller than it, hanging from the notch where there is one: the zones drawn small and the name of the zone with the focus), MenuBarIslandModel, MenuBarIslandView
    ├── Snap/                SnapDragController, SnapZoneOverlay, SnapOverlayModel, SnapOverlayView
    ├── Editor/              EditorController, LayoutEditing (port), EditorModel, EditorView, EditorPanel,
    │                        EditorZone, SplitTarget
    └── Settings/            SettingsView (tabs), SettingsTab, SettingsNavigation, OrderingTarget, LayoutsPane, ZonesPane, StackingPane, TrackpadPane, ShortcutsPane, UpdatesPane, UpdatesModel, SettingRow,
                             SliderSettingRow, ScreenLayoutsSection, AppsPane, IgnoredAppsSection, LayoutCard, LayoutFloatingRow (the floating zone of a layout: on or off, the zone it floats over, its size), LayoutFile, LayoutGapRow, LayoutMiniature, LayoutPresetSheet, KeyRecorder, GeneralPane, LaunchAtLoginModel,
                             FixedWindowTitle, TitleLockingView,
                             WindowPresenceReporter, WindowPresenceView,
                             PillContent+Title, PillPosition+Title, TrackpadMethod+Title, View+CappedHeight, SnapTrigger+Title, AppLanguages
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
| `StripLayout` / `StripGeometry` | A screen's layout with the zones (`Overflow`) beyond its left and right edges as one strip; where each zone stands for a scroll offset, how far the screen may scroll and where a scroll comes to rest: whenever any vertical line between zones (on the screen or in an area) is at the left or the right edge of the screen (`StripLayout.rests`; `areaRests`, the far edges of the areas, is what the layout editor's view rests at). Pure arithmetic. `Parking` tells where a window waits when its zone is out of sight (one pixel on the display, at a side with no display beside it). |
| `StripScroller` / `StripViewport` | A scroll (the shortcut or `EdgeScroller`) moves the screen along its strip: pictures of the windows in front glide (the render server moves them, so they glide whatever the apps or the machine do) while the real windows wait at the display's edge; the pictures glide on to the nearest rest position, the windows are put where they belong, and the pictures fade away. A press while a scroll runs gives it a new aim (the next rest position, or back); fingers or a press that come while it lands (its windows being put in place, its pictures about to give way) take it over: the pictures stay, the windows are parked again and the new scroll goes on from where it came to rest (without pictures, a press waits for the landing, three at most). Fingers (four) that come down while a scroll glides take it over where it is, whatever started it (keys, wheel, the pointer at the edge, earlier fingers). Pictures taken in earlier scrolls stand in at once. The viewport remembers each screen's offset for `ZonePlanner`. |
| `EdgeScroller` | Push the pointer to the left or right edge of a screen and the zones beyond that edge scroll into view; the pointer must leave the edge to scroll again. The ends of the edge (120 pt at each corner) are left to macOS Hot Corners. |
| `WindowMover` | Writes the positions of many windows off the main thread, one app at a time, latest wanted place only. |
| `StackCoordinator` (floating zone) | A zone with `isFloating` (`PlannedZone`) never stacks (no pill, no swipe or step through its windows): it shows the window that has the focus (`ZoneStack.shownID`) and keeps the others beyond the edge; a window that takes the focus (Dock, Cmd+Tab) glides in from beyond the edge and the one it replaces glides out, with the spring of the slides inside a zone: the one that goes as a picture (the real window changes under it), the one that comes as itself (so its shadow is its own). It sends its windows, as a picture that glides out from behind the window that took the focus (raised over the picture's panel) and in front of the others (`FloatStaging`; the window itself glides without Screen Recording or with motion reduced), to its place beyond the screen's right edge (`awayFrame`, nil where a display lies there: they stay) when the focus goes elsewhere; they glide back when it returns (`followFocus`, also at every app activation). PaneFlip's own windows in front change nothing. A window that cannot be resized (`WindowSystem.isResizable`) keeps its size and stands in the middle of the zone. Where zones overlap, the smaller one wins the drop. |
| `StackMemory` | Remember which app belongs to which zone, in the user's order. Knows nothing about windows. |
| `StackCoordinator` | Keep live stacks and memory in step with real windows (snap, select, release). |
| `ZoneCarousel` | Slide the chosen window of a zone in beside the one in front: both are photographed (Screen Recording), the pictures slide inside the zone while the real windows swap underneath, so nothing shows outside the zone. A press in the same direction while it runs carries the slide on to the next window (one more picture, the same spring); a choice it cannot take on yet (the other way, or while a picture is being taken) waits in `StackCoordinator` and is tried again when the carousel is free (`onFree`), three at most. Fingers that come down while the pictures of a swipe still glide take them over where they are (`StripScroller` does the same with the layout). |
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
| `SnapDragController` | Window drag + trigger key (or a shake of the mouse during the drag) → snap. |
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
