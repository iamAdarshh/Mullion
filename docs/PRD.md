# Mullion: Product Requirements

| | |
|---|---|
| **Owner** | Adarsh Choudhary (@iamAdarshh) |
| **Status** | Draft v0.1 (planning) |
| **Last updated** | 2026-10-19 |

## 1. Problem
macOS window management is still mostly manual. Since Sequoia, macOS can tile to halves and quarters, but it has no thirds or sixths, no custom layouts, no saved workspaces, and only limited multi-monitor control. Magnet covers the basics but has no custom zones or saved layouts. PowerToys solves this on Windows (FancyZones, Workspaces, Grab And Move), but nothing comparable on the Mac is both free and open source.

## 2. Goals
1. Match Magnet's snapping feature set, with a free and open-source licence (v1).
2. Add the PowerToys window features that Magnet lacks: zones, grab & move, app memory, and workspaces (v2).
3. Feel native. The app should be fast (snap in under 50 ms), use little memory (under 40 MB at idle), produce no visible flicker, and behave correctly on multiple displays.
4. Be trustworthy: use only public APIs, make no network calls, and keep the codebase readable for contributors.

## 3. Non-goals
| Not doing | Why |
|---|---|
| Always-on-top for other apps' windows | No public API exists. It would need private SkyLight APIs or disabling SIP (see [ADR-0003](adr/0003-public-apis-only.md)). |
| Automatic tiling (BSP, dwindle) | This is a different product category; AeroSpace and yabai already cover it. |
| Moving windows between Spaces | No public API exists. |
| Mac App Store distribution | Sandboxing conflicts with Accessibility control of other apps (see [ADR-0002](adr/0002-distribution-outside-app-store.md)). |
| Non-window PowerToys utilities (color picker, rename, …) | Out of scope. Mullion is a window manager. |

## 4. Users
- **Switcher:** came from Windows and expects Win+Arrow-style snapping and drag-to-edge.
- **Multi-monitor developer:** uses a laptop with one or two external monitors (one possibly vertical) and wants repeatable layouts.
- **Ultrawide user:** wants thirds, sixths and custom zones instead of just halves.

## 5. Concepts and terms
- **Action:** a named window operation, for example `leftHalf` or `nextDisplay`. Every shortcut, menu item and drag target maps to exactly one action.
- **Target rect:** the frame an action produces, computed from the screen's *visible frame* (which excludes the menu bar and Dock) and the gap setting.
- **Snap area:** a hot region along a screen edge or corner that triggers an action while the user is dragging.
- **Zone / layout:** (v2) a user-defined set of rectangles, normalised to 0…1 of the visible frame.
- **Workspace:** (v2) a saved set of apps and their window frames, grouped by display.

---

## 6. v1 requirements

### 6.1 Window actions
All target rects are computed against the **visible frame** of the screen that contains most of the window, then inset by the **gap** setting (default 0 pt, range 0–40). Gaps apply to tiled actions (halves, quarters, thirds, two-thirds, sixths, Maximize) and vertically to Maximize Height: edges on the screen edge are inset by the full gap and edges shared with a neighbouring tile by half of it, so two snapped windows sit exactly one gap apart. Every target rect is rounded to whole points on its edges, so neighbouring tiles touch exactly.

| Action ID | Name | Geometry (fraction of visible frame) |
|---|---|---|
| `leftHalf` / `rightHalf` | Left / Right Half | w ½, full height |
| `topHalf` / `bottomHalf` | Top / Bottom Half | full width, h ½ |
| `topLeft` `topRight` `bottomLeft` `bottomRight` | Quarters | w ½ × h ½ |
| `firstThird` `centerThird` `lastThird` | Thirds | w ⅓ (h ⅓ on portrait screens) |
| `firstTwoThirds` `lastTwoThirds` | Two-thirds | w ⅔ (h ⅔ on portrait) |
| `topLeftSixth` … `bottomRightSixth` (6) | Sixths | w ⅓ × h ½ (w ½ × h ⅓ on portrait) |
| `maximize` | Maximize | full visible frame |
| `almostMaximize` | Almost Maximize | 90 % of the visible frame, centred (percentage configurable) |
| `maximizeHeight` | Maximize Height | keep x and width, full height |
| `center` | Center | keep size, centre it (clamped to the visible frame) |
| `restore` | Restore | the frame from before Mullion first moved this window |
| `nextDisplay` / `previousDisplay` | Move to Next / Previous Display | keep the window's relative position and size proportionally, clamped |
| `larger` / `smaller` | Grow / Shrink | ±30 pt on each side (step configurable), clamped |

"First" and "last" mean left and right on landscape screens, top and bottom on portrait screens (where height > width). On portrait screens the six sixths form 2 columns × 3 rows, in reading order: `topLeftSixth`, `topCenterSixth` (first row), `topRightSixth`, `bottomLeftSixth` (second row), `bottomCenterSixth`, `bottomRightSixth` (third row). Shrink never makes a dimension smaller than 25 % of the visible frame.

**Acceptance criteria**
- AC-1: Each action produces the expected rect to within 1 pt on 1×, 2× and mixed-scale display setups (unit-tested in `MullionCore`).
- AC-2: If an app enforces a minimum size larger than the target, the window is placed at the target's origin and stays inside the visible frame. It must not end up on another display. Exception: when the target itself already spans displays (*Grow* or *Restore* on a window that spans two displays), the window stays at the target's origin and is not pulled onto one screen.
- AC-3: Native full-screen windows, the desktop, and system UI (Dock, menu bar extras) are ignored silently.
- AC-4: Actions on a window with no focus (for example, Finder with no windows open) do nothing and play no error sound.

### 6.2 Cycling (repeat to cycle)
If the user triggers the same half action twice in a row on the same window, and the window already matches that action's current size, the size steps through **½ → ⅔ → ⅓ → ½**. The setting is *Repeated shortcuts: Cycle sizes / Do nothing / Move to next display* (default: Cycle sizes).
- "Twice in a row" means the last action Mullion applied to that window was this action and the window is still within 2 pt of where Mullion put it. There is no time limit. A window the user has moved since starts again at ½.
- Only the four half actions repeat this way.

### 6.3 Restore
- Before the first Mullion-initiated move of a window, its frame is saved in memory. It is keyed by the window's `AXUIElement` and cleared when the window closes (detected when its app quits, or after the next action on that app, when its element reports it is gone) or after a successful restore. Mullion never queries other apps' windows just to clean up, so a frozen app can't slow down shortcuts. If the saved frame's display has been disconnected, the window is restored onto the nearest connected display.
- `restore` brings back that frame. Manually dragging a snapped window away from its snapped position and dropping it outside every snap area restores its original *size* under the cursor: the cursor stays the same fraction of the way across the title bar, the top edge stays where it was dropped, and the window is kept inside the visible frame. Unlike Magnet and Windows, the size changes at the drop rather than as the drag starts, because the app ignores Accessibility requests while it runs its window-drag loop. Afterwards the window counts as unsnapped and *Restore* does nothing. Dropping it back where it was keeps it snapped; holding the snap modifier (⌥) or an ignored app leaves it alone. On by default (Settings → General). It works with drag to snap turned off too: Mullion still follows drags, without previews or snapping.

### 6.4 Drag to snap
- Dragging a window by its title bar into a snap area shows a translucent **preview overlay** of the target rect, in the accent colour (or a colour and opacity chosen in Settings → Drag) and with gaps applied, exactly as the shortcut would place it. Releasing the mouse applies the action on the display the preview was on; moving out of the area hides the preview.
- Default snap areas:

| Area | Action |
|---|---|
| Left / right edge | Left / Right Half |
| Any corner | The matching quarter |
| Top edge | Maximize |
| Bottom edge, left / middle / right thirds | First / Center / Last Third |
| Bottom edge, sliding from one third into a neighbouring third | First / Last Two-thirds |
| Ultrawide displays (aspect ratio ≥ 21:9), top edge split into thirds | Top sixths (top centre remains Maximize) |

- The area thickness is 5 pt for edges and 20 pt for corners (both configurable).
- On a portrait display the bottom edge snaps to the Bottom Half, because thirds run top to bottom there.
- An edge shared with another display is still a snap area on each side; the cursor passes through it on the way to the other display. A drop inside it, or less than 8 pt past it (hysteresis), snaps on the display the area belongs to.
- Snap areas can be remapped per area in Settings → Drag (v1.1; the defaults above ship in v1.0).
- Holding **⌥ while dragging** temporarily disables snapping. Settings → Drag can change the key to ⌃ (⇧ is kept for Zones, and ⌘ is macOS's gesture for dragging background windows). On a Force Touch trackpad, entering a snap area gives a light haptic tap (on by default).
- Windows of apps on the ignore list never snap when dragged. Keyboard shortcuts and menu actions still work on them, because those are a deliberate request for the frontmost window. The menu's **Ignore [frontmost app]** item adds the app to the list, and choosing it again (it shows a checkmark) takes it off.
- Known limitations (v1):
  - Dialogs and floating panels show a preview but don't snap at the drop: Mullion only moves standard windows, and during the drag it can't tell them apart.
  - A tab torn off into a new window (Safari, Chrome) doesn't snap: the window being dragged is new, and the window that was clicked never moves.
  - While Mullion itself is the active app (its welcome window is in front), pressing or releasing ⌥ only takes effect on the next mouse movement.
- AC-5: The preview appears within 1 frame (under 16 ms) of entering an area and never flickers when hovering on the boundary between two areas (use hysteresis).
- AC-6: Snapping works on every connected display, including a display placed above or below the main display.

### 6.5 Multi-display
- `nextDisplay` and `previousDisplay` order displays by their x position, then y (left to right, top to bottom), and wrap around from the last display to the first.
- If the window was snapped, it keeps the same *action* on the new display. For example, a left-half window becomes the left half of the next display. Otherwise its frame is scaled proportionally.
- Up to 6 displays are supported and tested. More may work.

### 6.6 macOS tiling conflict (Sequoia 15+)
- At launch, once Accessibility is granted, and whenever the Settings window comes to the front, Mullion reads the `com.apple.WindowManager` preferences `EnableTilingByEdgeDrag`, `EnableTopTilingByEdgeDrag` and `EnableTilingOptionAccelerator`. The last one ("Hold ⌥ key while dragging windows to tile", on by default) makes ⌥ hand a drag to the system tiler, which clashes with ⌥ disabling Mullion's snapping, so the notice mentions it too, but only while ⌥ is Mullion's snap modifier. While drag to snap is off there is nothing to clash with, and no notice.
- Settings → Drag shows the same text as a warning at the top for as long as a conflicting setting is on, with **Open Desktop & Dock Settings**. It ignores *Don't Show Again* and clears as soon as the user comes back with tiling off.
- A key that is missing means the user never changed it, so it has its macOS default (on). Before macOS 15 there is no system tiling and nothing is read.
- If any is enabled and drag-to-snap is on, Mullion shows a notice at most once per launch, and only once Accessibility is granted, so it never covers the welcome window. It names the macOS settings to turn off and has **Open Desktop & Dock Settings** and **Don't Show Again** buttons. *Don't Show Again* hides it for good; after *Open Desktop & Dock Settings*, the next launch checks again and stays quiet if tiling is now off. Mullion never writes these preferences itself.

### 6.7 Menu bar
- A template icon (monochrome, shaped like a mullion window glyph).
- The menu lists every action grouped by type (Halves, Quarters, Thirds, Sixths, Other, Displays), each with its shortcut shown on the right. It also has **Ignore [frontmost app]**, **Settings…**, **About**, and **Quit**.
- The menu bar icon can be hidden. If it is, launching the app a second time opens Settings. While Accessibility access is missing, the icon is shown anyway (with its warning, §6.9.3), and launching the app again opens the welcome window instead.

### 6.8 Settings window (SwiftUI)
| Tab | Contents |
|---|---|
| General | Launch at login, show menu bar icon, repeated-shortcut behaviour, gap size, almost-maximize %, restore-on-drag-away |
| Shortcuts | A recorder for every action, *Restore defaults*, conflict warnings |
| Drag | Drag-to-snap on/off, the modifier to disable snapping (⌥ or ⌃), edge and corner size, preview colour and opacity, haptic feedback (Force Touch trackpads) |
| Ignored Apps | Add or remove apps by bundle ID, with a picker for running apps |
| Advanced | Export and import the config as JSON (`mullion-config.json`, versioned; import replaces everything, and what the file leaves out gets its default), reset everything (launch at login is left alone, since macOS owns it), *Copy Diagnostics* (version, macOS, Accessibility, displays, tiling and settings for a bug report, with ignored apps only counted), *Open Console*. Mullion logs only to the unified system log (`os.Logger`), so there is no log folder or verbose switch |
| About | Version, licence, GitHub link, acknowledgements |

### 6.9 Onboarding and permissions
1. On first launch, a welcome window explains *why* Accessibility access is needed, and its button calls `AXIsProcessTrustedWithOptions` with the prompt option.
2. Mullion polls for trust once per second while the welcome window is open, and continues automatically once access is granted.
3. If trust is revoked while running, the menu bar icon shows a warning badge, all actions are disabled, and the menu shows *Grant Accessibility access…*. Mullion's global shortcuts are released while trust is missing, so other apps receive those keys (a registered hotkey would otherwise swallow them). macOS has no public notification for trust changes, so Mullion re-checks every 5 s (timer with tolerance, to keep idle CPU near zero) and immediately whenever the menu opens or an action runs from the menu or a shortcut. A re-grant is therefore picked up within 5 s, or at once when the menu opens, and the shortcuts come back with it. *Grant Accessibility access…* reopens the welcome window.

### 6.10 Non-functional requirements
| ID | Requirement |
|---|---|
| NFR-1 | Under 50 ms from key press to window placed (p95, measured using a signpost) |
| NFR-2 | Idle CPU about 0 % and under 40 MB RSS at idle |
| NFR-3 | No network access in v1. The app is built with Hardened Runtime. |
| NFR-4 | VoiceOver labels on every Settings control. Supports reduced motion: the drag preview still fades in and out, but jumps between snap areas instead of sliding. |
| NFR-5 | Localisable from day one (String Catalog). Ships with English, and German as a stretch goal. |
| NFR-6 | Crash-free: no force-unwraps on AX results, and every AX call handles errors |

---

## 7. v2 requirements (overview)
Each v2 feature gets its own spec in [docs/features/](features/) before implementation starts.

| Feature | Spec | Summary |
|---|---|---|
| Zones | [features/zones.md](features/zones.md) | Custom layouts, an editor, ⇧-drag to zone, spanning, one layout per display, hotkey switching |
| Grab & Move | [features/grab-and-move.md](features/grab-and-move.md) | Modifier + drag anywhere to move, modifier + right-drag to resize |
| App memory | [features/app-memory.md](features/app-memory.md) | Opt-in: put an app's new window into its last zone |
| Workspaces | [features/workspaces.md](features/workspaces.md) | Capture, edit and launch sets of apps and positions |
| Window thumbnail | [features/window-thumbnail.md](features/window-thumbnail.md) | *Exploratory.* A live, view-only mini copy of a window (ScreenCaptureKit) |

## 8. Success metrics (for a public OSS project)
- v1.0 tagged, with a signed and notarized build or a clearly documented unsigned build
- Zero P0 bugs open for more than 7 days
- The README has a GIF demo, and setup from a fresh clone takes under 10 minutes
- At least 5 external contributors or 100 GitHub stars within 6 months of v1.0 (aspirational)

## 9. Open questions
1. Should almost-maximize and gaps apply to drag snapping as well as shortcuts? (Proposed: yes, one geometry engine for everything.)
2. Distribution: notarized DMG (needs the paid Apple Developer Program) or unsigned plus a Homebrew cask? Decide before M3.
3. Should Zones replace the v1 snap areas when enabled, or sit alongside them (⇧ for zones, plain drag for snap areas)? Proposed: alongside. See zones.md.
