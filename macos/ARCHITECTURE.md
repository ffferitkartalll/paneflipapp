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
│   ├── Layout/              LayoutNode, SplitDivider, NamedLayout, DisplayStairs (whether the displays form a staircase going up to the right, so that no zone beyond a display's edge lands on another display), StairStep, DeskArrangement (where the displays stand on the desk, set by the user), DeskSnap (where a dragged display comes to rest: flush against another, lined up with its edges and middle), DeskPointer (where the pointer goes when pushed against a display's edge, by the desk arrangement), NamedLayout+File (a layout as a file: export, import), LayoutPreset, SplitSnap (the proportions a split line sticks to: 1/4, 1/3, 1/2, 2/3, 3/4), Overflow, StripLayout, StripGeometry, PagedScroll (a swipe or a wheel notch as a step to the next screen), Parking, DockHome (the display that was unplugged with the Dock on it), ScreenLayouts, LayoutRepository, ZoneGlyph (a screen's zones, those beyond its edges too, drawn small in a row), CarouselCards (the widths and places of the cards of a row that slides through a frame), ZoneDirection, ZoneNeighbour (the zone beside a zone in a direction), ZoneCrossing (the zone entered on the next display, at the same place along the edge), ZoneRemapper
│   ├── Stacks/              StackRecord, LayoutSlot, LayoutApp, StackMemory (what belongs where, in what order), TabNaming, ScrubGesture (a swipe through a zone's windows: how far, how fast, what it chooses), FingerSwipe (the fingers on the trackpad as a swipe with three or four: when it begins and ends), AxisLock (a swipe is horizontal or not, decided in its first points)
│   ├── Settings/            AppSettings, SettingsValues, SettingsStorage (port), SnapTrigger, KeyChord, PlacementKey (the keys of the choice of a zone), TrackpadMethod
│   ├── Updates/             AppVersion
│   └── Persistence/         DocumentStore (port)
└── PaneFlip/                The macOS app.
    ├── App/                 PaneFlipApp, AppContainer (composition root), AppLauncher (permission gate), AppAccent (the colour the app lights things with: its own green under Multicolor, else the system's accent), SettingsWindowOpener (opens the Settings window through the "Settings…" item the Settings scene puts in the main menu), MenuBarController (the menu bar icon: a left click switches PaneFlip on or off, a right click opens MenuContent as a menu; the icon is filled while on, outlined while off), MenuContent, MenuLayouts (layout switcher in the menu), MenuBarLabel
    ├── Permissions/         Permission, PermissionChecking (port) ← SystemPermissions, PermissionsModel,
    │                        PermissionsView, PermissionRow, PermissionsWindowController
    ├── Platform/            Ports, their value types and adapters:
    │                        WindowSystem ← AXWindowSystem (+ WindowRef),
    │                        WindowSnapshotting ← ScreenCaptureWindowSnapshots,
    │                        SlideStaging ← PanelSlideStage, ScrollStaging ← PanelScrollStage (both draw on StagePanels),
    │                        DisplayLinkMetronome (a function called at every refresh of a screen),
    │                        ScreenProviding (+ ScreenInfo, DockArea) ← CGSScreenProvider,
    │                        AppCatalog (+ AppInfo) ← WorkspaceAppCatalog,
    │                        BrandGlyphSource ← CDNBrandGlyphs,
    │                        ReleaseChecking (+ ReleaseInfo) ← GitHubReleaseChecker,
    │                        UpdateInstalling ← DiskImageUpdateInstaller (downloads the release disk image, checks its signature against the running app, swaps the app after it quits with `UpdateSwapScript`, which gives up if the app does not quit),
    │                        WindowFocus (brings one window of an app forward and makes it key as a click does, the app's other windows staying behind; the window server's calls are found at run time), EventTapPointerCrossing (puts the pointer on the display beside, by the desk arrangement, when it is pushed against an edge), ScrollSwitchListening ← EventTapScrollSwitch (the mouse wheel with the keys held steps through a zone's windows or the layout, and so do two fingers with the keys held when the `TrackpadMethod` setting is `keysAndTwoFingers`; over the open island, with no key held, the wheel and two fingers are the layout's) and MultitouchSwipes (when it is `threeAndFourFingers`: three fingers on the trackpad lead the slide through a zone's windows, four the layout toward the zones beyond the edges; read through the system's private multitouch framework, loaded at start; `ScrollSwitchEvent`, `ScrollSwitchTarget`) and MouseButtonSwipes (the mouse's wheel button held and moved to the side leads the windows of the zone under the pointer; the pointer stays and shows a hand, which only holds while this app is the active one, so it is made active meanwhile; a click that never moves is posted again),
    │                        PlacementKeyListening ← EventTapPlacementKeys (the modifier keys that begin the choice of a zone for a window, and, while it is made, the arrow keys, Return and Escape; any other key or click ends it),
    │                        KeyShortcutListening ← EventTapKeyShortcut (four changeable shortcuts, `KeyChord` in Core: next/previous window of a zone, scroll toward the zones beyond the right/left edge; `KeyShortcut` is what a press asks for),
    │                        KeyStateProviding ← HardwareKeyState (+ SnapTrigger+KeyState),
    │                        LoginItemControlling ← SMAppServiceLoginItem,
    │                        ActivationPolicyControlling ← AppKitActivationPolicyController,
    │                        AppRelaunching ← WorkspaceAppRelauncher,
    │                        JSONFileStore, UserDefaultsSettingsStorage, MemoryPressureWatch (empties the picture cache)
    ├── Stacks/              ZoneStack, WindowChange, StackCoordinator, WindowRestorer, ClosedWindowMonitor, LayoutAppsService,
    │                        WindowAvailability, WindowSnapshot, ZoneCarousel, WindowGlide, WindowMover,
    │                        WindowPictureCache (pictures of windows taken ahead of time: bounded by bytes, age 60 s and the zone's size),
    │                        CachedWindowSnapshots (a WindowSnapshotting that answers from the cache and photographs only the misses; a window in front is live),
    │                        PictureKeeper (when to photograph: a window left the focus, or 0.5 s after everything came to rest; never while moving)
    ├── Zones/               ZonePlanner, DeskPointerRouter (keeps the plan of the displays on the desk for the pointer), DeskSpace (moves a rectangle from where the system arranges the displays to where the user says they stand on the desk), ZoneFlash (outlines the zone the focus went to), ZoneEngine, ZonePlacement (sends the focused window to a zone chosen in the island by keys: the modifier keys open it, the arrow keys move the choice, Return places, Escape cancels), ZonePicking (port: the island as a place to choose a zone in), StripPreview (the map of a strip, shown in the layout editor), ScrollSwitchHandler (what the scroll with the keys held asks for), LayoutService; ports LayoutManaging, DisplayChangeHandling, LayoutAppsEditing (+ LayoutAppEntry, LayoutWindowEntry), ZonePresenting, ZoneRefreshing
    ├── Island/              MenuBarIsland (a ZonePresenting: the island in the menu bar, never taller than it: the zones drawn small, centred, the zone with the focus lit; where there is a notch it is not shown at rest and grows out of the notch under the pointer; a second, almost clear panel (the shield) lies exactly over the island and takes the mouse, so that nothing behind the island sees the pointer; the wheel and two fingers over the open island scroll the layout; a click on a zone of the open island's picture opens that zone's windows under it as a carousel: the front window fills a frame as large as the zone, centred, with the app's glyph in the middle and its title under it, the other windows lie against it, and the apps of the zone that are not open stand among them in the zone's order, a click opening them (IslandWindow, IslandCardAction (the quit, close, hide and minimize buttons in the top left corner and the remove-from-zone button in the top right one that the card under the pointer shows when the island is open under it (a card of an app that has quit or has no window shows two: open the app, remove it from the zone)), MenuBarIslandWindowsView, IslandShiftedRow (a row of that carousel: it reads the finger drag itself, so only its body re-runs per finger event), IslandCardsLayout (lays the cards out: the front one as wide as the frame, the others narrower, all alike, when they would not fit in the island; animatable)); the wheel and two fingers over it step through the windows, the `zoneWindows` scroll target), and a second click on it closes the frame again; a card of the row can be dragged along it to put its window in another place (the order of the zone's slots in the memory and of its cards); a window dragged onto a zone of the picture and kept there for a second opens that zone's row, and over it a grey card with a plus shows where the window would be put (`ZoneDropTarget`); IslandShieldView tells where the mouse goes down, is dragged and comes up), MenuBarIslandModel, MenuBarIslandView, IconFont
    ├── Snap/                SnapDragController, ZoneDropTarget, SnapZoneOverlay, SnapOverlayModel, SnapOverlayView
    ├── Editor/              EditorController, LayoutEditing (port), EditorModel, EditorView, EditorPanel,
    │                        EditorZone, SplitTarget
    └── Settings/            SettingsView (tabs), SettingsTab, SettingsNavigation, OrderingTarget, DisplaysPane (the displays as macOS arranges them and whether they form a staircase going up to the right), DisplayMap, DeskMap (the displays to drag to where they stand on the desk), LayoutsPane, ZonesPane, StackingPane, TrackpadPane, ShortcutsPane, UpdatesPane, UpdatesModel, SettingRow,
                             SliderSettingRow, ScreenLayoutsSection, AppsPane, IgnoredAppsSection, LayoutCard, LayoutFile, LayoutGapRow, LayoutMiniature, LayoutPresetSheet, KeyRecorder, GeneralPane, LaunchAtLoginModel,
                             FixedWindowTitle, TitleLockingView,
                             WindowPresenceReporter, WindowPresenceView,
                             TrackpadMethod+Title, View+CappedHeight, SnapTrigger+Title, AppLanguages
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
| `StripLayout` / `StripGeometry` | A screen's layout with the zones (`Overflow`) beyond its left and right edges as one strip; where each zone stands for a scroll offset, how far the screen may scroll and where a scroll comes to rest: at the screen's own layout and at the far edge of each area, from one screen to the next (`StripLayout.areaRests`, which the layout editor's view rests at too). Pure arithmetic. `Parking` tells where a window waits when its zone is out of sight (one pixel on the display, at a side with no display beside it). |
| `StripScroller` / `StripViewport` | A scroll (the shortcut, the wheel or two fingers over the open island) moves the screen along its strip: pictures of the windows in front glide (the render server moves them, so they glide whatever the apps or the machine do) while the real windows wait at the display's edge; the pictures glide on to the nearest rest position, the windows are put where they belong, and the pictures fade away. A press while a scroll runs gives it a new aim (the next rest position, or back); fingers or a press that come while it lands (its windows being put in place, its pictures about to give way) take it over: the pictures stay, the windows are parked again and the new scroll goes on from where it came to rest (without pictures, a press waits for the landing, three at most). Fingers (four) that come down while a scroll glides take it over where it is, whatever started it (keys, wheel, earlier fingers). Pictures taken in earlier scrolls stand in at once. A screen with no window in any zone has nothing to photograph or park: the scroll still glides (or follows the fingers) for the frame of the island, and the layout goes there when it ends. The viewport remembers each screen's offset for `ZonePlanner`. |
| `WindowMover` | Writes the positions of many windows off the main thread, one app at a time, latest wanted place only. |
| `StackMemory` | Remember which app belongs to which zone, in the user's order. Knows nothing about windows. |
| `StackCoordinator` | Keep live stacks and memory in step with real windows (snap, select, release). Keeps the last few `WindowChange`s (a window added to a zone, taken out of one, or enlarged for 15 seconds by `enlargeFocused`) for `undoLast`; `onWindowChange` tells the island, which shows the line with the Undo button. |
| `ZoneCarousel` | Slide the chosen window of a zone in beside the one in front: both are photographed (Screen Recording), the pictures slide inside the zone while the real windows swap underneath, so nothing shows outside the zone. A press in the same direction while it runs carries the slide on to the next window (one more picture, the same spring); a choice it cannot take on yet (the other way, or while a picture is being taken) waits in `StackCoordinator` and is tried again when the carousel is free (`onFree`), three at most. Fingers that come down while the pictures of a swipe still glide take them over where they are (`StripScroller` does the same with the layout). |
| `WindowGlide` | Move a window the user just dropped from where it is to its zone in a short ease-out glide (steps follow the clock, off the main thread, the last one exact; no glide with Reduce Motion). |
| `UpdatesModel` | Ask, when the user presses the button, whether a newer release exists and install it when the user asks. Nothing is checked on its own. |
| `WindowRestorer` | Put running windows in the zone their app belongs in: remembered ones in their slots, every other window of the app next to them. |
| `ClosedWindowMonitor` / `WindowAvailability` | Notice closed, hidden or minimized windows. The system window list is read off the main thread, one read at a time; the answer is dropped if windows moved or the stacks changed meanwhile. |
| `ZonePlanner` | Compute which zones exist and where, for each screen's scroll: in view, or waiting beyond a display's edge. |
| `ZoneEngine` | Re-layout on desktop/display changes and run housekeeping. |
| `LayoutService` | Apply layout edits and carry their consequences to windows and memory. |
| `IconFont` | Single-colour glyphs for cards (system glyph table, brand glyphs, or the app icon's shape). |
| `CDNBrandGlyphs` | Fetch a brand glyph from a public icon set once and keep it on disk; asks nothing while the setting is off. |
| `LayoutAppsService` | Edits which app belongs in which zone of a layout, and in what order of cards; lets the restorer place the windows. |
| `SnapDragController` | Window drag + trigger key → snap; a drop on a zone of the island snaps too. |
| `ZoneDropTarget` | Port: a place besides the screen (the island) where a dragged window can be dropped on a zone. |
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
after the placement and stops `unsnap`, the shortcut, title and focus following and re-framing of held windows; the island is
hidden, and `ClosedWindowMonitor` and `WindowRestorer` do nothing. The settings, layouts and remembered apps are the same in
both modes, and nothing remembered is read or changed while it is on.

## Motion and periodic work

- `StackCoordinator.isMoving` is true while a layout scrolls, a zone's windows slide or the fingers lead them. Every periodic job that asks other
  apps' windows or lists windows (`ZoneEngine.tick`, `ClosedWindowMonitor`, the island's refresh, `StripScroller.warm`) does nothing while
  it is true; skipped ticks are not queued, the next one catches up.
- One master per animation: the strip glide is driven by the `StripScroller` frame and its island mirror is started from the same call; the island
  keeps its own deferral of the SwiftUI write because the starting value must be drawn before the animation begins.
- Pictures: `PictureKeeper` fills `WindowPictureCache` (it touches nothing else); `CachedWindowSnapshots` serves the carousel and the strip from it. `StripScroller.kept` is a second, older cache of pictures that can be folded into this one later.
