# Architecture

## 1. Big picture
```
┌──────────────────────────── Mullion.app (AppKit + SwiftUI) ───────────────────────────┐
│                                                                                       │
│  Input                        Coordination                   Output                   │
│  ─────                        ────────────                   ──────                   │
│  HotkeyService ──┐                                      ┌──► WindowMover (AX)          │
│  (KeyboardShortcuts)│        ┌──────────────────┐       │                             │
│  MenuBarController ─┼──────► │  ActionDispatcher │ ─────┤──► OverlayController         │
│  DragMonitor ───────┤        │  (@MainActor)     │       │    (preview / zones / HUD)   │
│  (NSEvent monitor)  │        └────────┬─────────┘       │                             │
│  GrabTap (v2) ──────┘                 │                 └──► Stores (JSON / Defaults)  │
│  (CGEventTap)                         ▼                                               │
│                         ┌──────────────────────────────┐                              │
│                         │   MullionCore (Swift pkg)    │  pure, no AppKit, 100% tested│
│                         │  Geometry · Actions · Snap   │                              │
│                         │  Areas · Zones · Config      │                              │
│                         └──────────────────────────────┘                              │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

**The rule.** `MullionCore` decides *where* a window goes. The app target decides *which* window it is and *how* to move it. Every pixel calculation lives in Core and is unit-tested. The app target is a thin layer over system APIs.

## 2. Repository layout (target state after M0)
```
mullion/
├── project.yml                  # XcodeGen spec – source of truth for the Xcode project
├── Makefile
├── Packages/
│   └── MullionCore/
│       ├── Package.swift
│       ├── Sources/MullionCore/
│       │   ├── Geometry/        # UnitRect, ScreenGeometry, CoordinateSpace, Gaps
│       │   ├── Actions/         # WindowAction enum, ActionCalculator, CycleState
│       │   ├── Snap/            # SnapArea, SnapAreaResolver (hysteresis)
│       │   ├── Zones/           # ZoneLayout, templates, hit-testing (v2)
│       │   ├── Workspaces/      # Workspace model + matching (v2)
│       │   └── Config/          # Codable config, schema migration
│       └── Tests/MullionCoreTests/
├── App/
│   ├── Sources/
│   │   ├── App/                 # MullionApp.swift, AppDelegate, lifecycle
│   │   ├── Accessibility/       # AXWindow, AXPermission, AXError+, AXObserver wrapper
│   │   ├── Input/               # HotkeyService, DragMonitor, GrabTap (v2)
│   │   ├── Dispatch/            # ActionDispatcher, RestoreStore
│   │   ├── Overlay/             # OverlayPanel, PreviewView, ZoneOverlay, HUD
│   │   ├── MenuBar/             # MenuBarController, icon
│   │   ├── Settings/            # SwiftUI settings tabs
│   │   ├── Onboarding/
│   │   └── System/              # Screens (NSScreen helpers), DisplayID, LoginItem, SystemTilingCheck
│   ├── Resources/               # Assets.xcassets, Localizable.xcstrings
│   ├── Info.plist
│   └── Mullion.entitlements
├── App/Tests/                   # XCTest/Swift Testing for app-level logic with fakes
├── docs/
└── .claude/
```

## 3. Key technology choices
| Concern | Choice | ADR |
|---|---|---|
| Language/UI | Swift 6 (strict concurrency), AppKit for the menu bar, panels and event plumbing; SwiftUI for Settings and onboarding | [0001](adr/0001-native-swift-appkit.md) |
| Project generation | XcodeGen (`project.yml`) plus a local SPM package | [0004](adr/0004-xcodegen-and-core-package.md) |
| Window control | Accessibility API (`AXUIElement`) | [0003](adr/0003-public-apis-only.md) |
| Hotkeys | [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (MIT). It uses Carbon `RegisterEventHotKey`, so no Input Monitoring permission is needed, and it includes a recorder UI. | [0005](adr/0005-dependencies.md) |
| Drag detection | `NSEvent.addGlobalMonitorForEvents` (passive) | [0006](adr/0006-drag-detection.md) |
| Grab & Move (v2) | Active `CGEventTap` | [0006](adr/0006-drag-detection.md) |
| Login item | `SMAppService.mainApp` (built in) | |
| Persistence | `UserDefaults` for preferences; JSON files in Application Support for layouts, workspaces and app memory | |
| Logging | `os.Logger`, subsystem = bundle ID | |
| Distribution | Outside the App Store; an ad-hoc signed DMG (not notarized, see [RELEASING.md](RELEASING.md)) and a Homebrew cask in our own tap | [0002](adr/0002-distribution-outside-app-store.md) |

## 4. Coordinate systems (read this before touching geometry)
macOS uses two global coordinate spaces, and mixing them up is the most common source of bugs in window managers.

| Space | Origin | Used by |
|---|---|---|
| **AppKit / Cocoa** | Bottom-left of the **primary** screen, y goes up | `NSScreen.frame`, `visibleFrame`, `NSEvent.mouseLocation`, `NSWindow.frame` |
| **Quartz / AX ("flipped")** | Top-left of the **primary** screen, y goes down | `AXUIElement` position, `CGEvent.location`, `CGWindowList` bounds |

Conversion is done in exactly one place, `MullionCore/Geometry/CoordinateSpace.swift`:
```
axY = primaryScreenHeight - (appKitY + height)
```
where `primaryScreenHeight = NSScreen.screens[0].frame.height`. That is the screen containing the menu bar, **not** `NSScreen.main`, which is the screen with the key window.
- All Core APIs take and return **AX space**, because that is what we read from and write to windows. Screens are converted into AX space once, when the app builds its `ScreenGeometry` values.
- Tests must cover screens placed left of, right of, above and below the primary screen, plus mixed scales.

## 5. Moving a window (AX details)
`AXWindow.setFrame(_:of:pid:order:)`, then `ActionDispatcher`:
1. If the app has `AXEnhancedUserInterface` = true (set by VoiceOver or some Electron and Chromium apps), set it to false, move the window, then restore it. Otherwise some apps animate or ignore the size change.
2. Write size and position in the order `FrameWrite.order` (Core) picks. A window coming from another display gets **size**, then **position**, then **size** again: macOS keeps a window's size within its current display, and the final size is needed after the move. On the same display, whichever order keeps the window more on screen goes first: resizing a right-half window to the full width in place would stretch it past the edge, where apps can cut the resize short ([#16](https://github.com/iamAdarshh/Mullion/issues/16)).
3. If the window came out smaller than the target (an app cut the resize short or dropped it), set position and size once more. Best effort: a failure here is logged, not thrown.
4. `ActionDispatcher` reads the frame back. If it still differs from the target by more than 2 pt (because of a minimum size), it re-anchors the window to the target's origin and clamps it inside the visible frame.
5. Every `AXUIElement*` call returns `AXError`. Wrap them in a `throws` API (`AXError.check()`) and never force-unwrap.
6. AX calls are synchronous IPC to the target app and can block if that app hangs. Set `AXUIElementSetMessagingTimeout(element, 0.25)` and do AX work off the main thread on a serial `AXQueue` actor. Only UI work goes back to `@MainActor`.

Finding the focused window: `AXUIElementCreateApplication(frontmostApp.pid)`, then `kAXFocusedWindowAttribute`. Filter by `kAXSubroleAttribute == kAXStandardWindowSubrole` and skip windows where `AXFullScreen` == true.

## 6. Drag-to-snap pipeline (M2)
```
leftMouseDown ──► remember the press point (no window lookup yet)
leftMouseDragged
   ├─ after 4 pt: frontmost window under the cursor or the press point, from CGWindowList (number,
   │  pid, bounds); the window may already be ahead of the press point, or still behind the cursor
   ├─ until it moves: has its origin moved with the same size? not within 30 pt → ignore this drag
   │  (text selection, scrollbars, resizing)
   ├─ SnapAreaResolver.resolve(cursor, screens, previous) → SnapArea?   [Core, pure]
   └─ OverlayController.show(preview: ActionCalculator.rect(area.action, screen))
every 0.25 s during a window drag: button up on two checks in a row ──► release was missed: cancel
leftMouseUp ──► hide overlay; if area: ActionDispatcher.perform(area.action, onDropped:, on: area.screen)
   │  └─ the app's main window, then its other standard windows, matched to the window-server bounds
   │     within 2 pt; else the main window if it has the same size within 30 pt (the app nudged it);
   │     asked again once if busy
   └─ no area, and the window was still at its last snap when the drag began (size within 2 pt,
      origin within 30 pt): DragAwayPlanner [Core] gives it its pre-snap size under the cursor
      (no AX call for windows Mullion never snapped)
flagsChanged / any mouse event ──► snap modifier (⌥ or ⌃) held? snapping off for the drag (preview hidden, drop leaves it alone)
drag start ──► app on the ignore list (bundle ID)? no preview, no snap, no drag-away for this drag
```
- During the drag the window is read from the **window server** (`CGWindowListCopyWindowInfo`), never over AX: the app is busy in its window-drag loop and every AX read times out. Only number, pid, layer and bounds are read, so no Screen Recording permission is needed. The AX element is looked up at the drop, when the app answers again: there is no public way to map a window number to an AX element, so the app's standard windows are matched by frame. The snap is planned on the drop's screen only, so a window still mostly on the neighbouring display snaps where the preview showed it, and *Restore* goes back to the frame from before the drag, or from before the first snap if Mullion had already snapped the window. The main window is tried first, because a title-bar drag makes the dragged window main and a hidden native tab can share its frame; a timeout aborts the search instead of costing one per window.
- macOS 15+ tiling: `SystemTilingCheck` only reads `com.apple.WindowManager` (`EnableTilingByEdgeDrag`, `EnableTopTilingByEdgeDrag`, `EnableTilingOptionAccelerator`; a missing key means on) and `TilingNoticeCoordinator` shows the notice once per launch; Settings → Drag re-reads them whenever its window becomes key (PRD §6.6). Mullion never writes these keys.
- Hysteresis: once an area is entered, the cursor has to move 8 pt past the area's edge before it counts as having left. This prevents flicker at boundaries.
- The overlay is one `NSPanel` per screen, created or updated when a window drag starts (so the first preview appears within a frame) and dropped for displays that are gone, with `ignoresMouseEvents = true`, `level = .statusBar`, and collection behaviour `[.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]`. Panels are reused across drags. A fade-out only orders its panel out if no fade started after it.

## 7. Concurrency model
- `@MainActor`: UI, menu, overlay, `ActionDispatcher` state.
- `actor AXQueue`: all AX reads and writes, serialised, so two snaps can never race on one window.
- The event monitor and tap callbacks do the minimum (copy the event data) and hop to the right actor.
- Swift 6 strict concurrency is on. `AXUIElement` is not `Sendable`, so wrap it in a `struct WindowRef: @unchecked Sendable` with a comment explaining why that is safe: it is an immutable CF reference, and every use goes through `AXQueue`.

## 8. Persistence and config
- **`UserDefaults`** (suite = bundle ID) for scalar preferences, accessed through a typed `Preferences` wrapper.
- **JSON files** (`layouts.json`, `assignments.json`, `workspaces.json`, `app-memory.json`) in `~/Library/Application Support/Mullion/`:
  - Each has a top-level `schemaVersion`, and a `Migrator` in Core upgrades older versions.
  - Writes are atomic (`Data.write(options: .atomic)`).
  - A file that fails to decode is renamed to `*.corrupt-YYYYMMDD-HHMMSS.json`, defaults are loaded, and the user sees a notice.
- **Export/import** bundles all of the above into one JSON file (`mullion-config.json`).

## 9. Permissions
| Permission | Needed for | When it's requested |
|---|---|---|
| Accessibility | Everything (moving windows, event taps) | First launch |
| Screen Recording | Window thumbnail (M9 only) | First use of that feature |
| Input Monitoring | **Not needed.** Carbon hotkeys and AX-trusted taps cover our needs. | Never |

## 10. Testing strategy (summary; full detail in [TESTING.md](TESTING.md))
- **Core**: Swift Testing, table-driven and exhaustive for geometry. Target ≥ 95 % line coverage.
- **App**: `WindowControlling` and `ScreenProviding` protocols with fakes, so `ActionDispatcher` and the drag pipeline can be tested without a real AX.
- **Manual**: a test matrix across displays, apps and macOS versions, run before each milestone exit.

## 11. Things that will bite you
- `NSScreen.main` is *not* the primary screen.
- `visibleFrame` changes when the Dock auto-hides or moves. Observe screen-parameter changes and the `com.apple.dock` preferences.
- Some apps (System Settings, some Catalyst apps) round sizes or enforce aspect ratios. Accept a 2 pt tolerance.
- Finder's desktop is a "window" of Finder. Skip windows with role `AXScrollArea` or no subrole.
- After an app relaunches, a window's `AXUIElement` changes. Never persist one.
- Rebuilding the app with a new ad-hoc signature can make macOS silently drop the Accessibility grant during development. See [SETUP.md §Troubleshooting](SETUP.md#troubleshooting).
