# Roadmap

Each milestone is a set of GitHub issues under a milestone of the same name. A milestone is **done** only when every exit criterion is met and the [manual test matrix](TESTING.md#manual-test-matrix) rows tagged for it pass.

Work proceeds in order. Do not start a milestone until the previous one is done, except for M9, which is exploratory.

```
v1.0 ─ M0 Scaffold → M1 Keyboard → M2 Drag → M3 Settings & Release
v2.x ─ M4 Zones core → M5 Zone editor → M6 Grab & Move → M7 App memory → M8 Workspaces
later ─ M9 Window thumbnail (exploratory)
```

---

## M0: Scaffold
Goal: an empty but correct app skeleton that every later milestone builds on.
- [x] `project.yml` (XcodeGen) defining the `Mullion` app target, the `MullionCore` local Swift package, and test targets
- [x] `Makefile` targets: `bootstrap`, `build`, `test`, `test-core`, `test-app`, `run`, `lint`, `format`, `clean`
- [x] The app runs as a menu bar agent (`LSUIElement = YES`) with a placeholder menu: *Settings…*, *Quit*
- [x] Accessibility onboarding flow (PRD §6.9)
- [x] `os.Logger` categories set up (`ax`, `hotkey`, `drag`, `layout`, `settings`)
- [x] CI is green: lint, `swift test` for MullionCore, and `xcodebuild build` for the app
- [x] The DEBUG build has a different bundle ID (`…mullion.debug`) so the Accessibility grant for the dev build doesn't conflict with a release install
- [x] `Config/Base.xcconfig` + `Config/Local.xcconfig.example` (gitignored `Local.xcconfig` holds `DEVELOPMENT_TEAM` for a stable debug signature; see SETUP.md §Troubleshooting)

**Exit criteria:** a fresh clone followed by `make bootstrap run` shows the menu bar icon and the permission prompt, and CI passes.

## M1: Keyboard snapping
- [x] `MullionCore/Geometry`: coordinate conversion (AppKit ↔ AX), visible frame, gaps, and every action in PRD §6.1, with 100 % unit-test coverage of the action math
- [x] `AXWindow` wrapper: get/set frame, focused window, minimum size handling, enhanced-UI workaround
- [x] Global hotkeys via the `KeyboardShortcuts` package, using the defaults from SHORTCUTS.md
- [x] Repeat-to-cycle (PRD §6.2)
- [x] Restore (PRD §6.3)
- [x] Next / previous display (PRD §6.5)
- [x] Every action is listed in the menu bar with its shortcut
- [x] Actions are disabled while Accessibility is revoked, and every action re-checks trust first (PRD §6.9.3)

**Exit criteria:** PRD AC-1 to AC-4 pass, and the test-matrix rows tagged `M1` pass on a laptop alone and on a laptop with one external display.

## M2: Drag to snap
- [x] Mouse monitor (`NSEvent` global monitor) and window-move detection
- [x] Snap-area engine in `MullionCore` with hysteresis (pure and unit-tested)
- [x] Preview overlay panel, one per screen, with reduced-motion support
- [x] ⌥ to disable snapping, and the ignore list
- [ ] Restore size when dragging a snapped window away
- [ ] Detection of the Sequoia tiling conflict and the notice (PRD §6.6)

**Exit criteria:** AC-5 and AC-6 pass, and the `M2` test-matrix rows pass, including a vertical display and an ultrawide (simulated with BetterDisplay or a real monitor).

## M3: Settings and v1.0 release
- [ ] SwiftUI Settings with every tab in PRD §6.8
- [ ] Launch at login via `SMAppService.mainApp`
- [ ] Config export/import (versioned JSON)
- [ ] App icon and menu bar template icon (original artwork)
- [ ] German localisation (stretch goal)
- [ ] README GIF and website/GitHub Pages (optional)
- [ ] `Makefile` release targets: `archive`, `notarize`, `dmg` (see [RELEASING.md](RELEASING.md))
- [ ] Decide on signing and notarization ([RELEASING.md](RELEASING.md)), then ship `v1.0.0`

**Exit criteria:** the full test matrix passes on macOS 14, 15, and the latest release, and the release checklist is complete.

---

## M4: Zones core (v2.0)
Spec: [features/zones.md](features/zones.md)
- [ ] Layout model and templates (columns, rows, grid, priority grid), persisted as JSON
- [ ] A layout assigned per display (keyed by display UUID)
- [ ] ⇧-drag shows zones; dropping applies the zone; ⇧⌘ spans zones
- [ ] Hotkeys: switch layout 1–9, move window to next/previous zone

## M5: Zone editor (v2.1)
- [ ] A full-screen editor overlay: split a zone by clicking it (⌥-click for a vertical split), drag dividers, merge zones, set the gap
- [ ] A canvas mode with freeform rectangles
- [ ] A layout gallery in Settings

## M6: Grab & Move (v2.2)
Spec: [features/grab-and-move.md](features/grab-and-move.md)

## M7: App memory (v2.3)
Spec: [features/app-memory.md](features/app-memory.md)

## M8: Workspaces (v2.4)
Spec: [features/workspaces.md](features/workspaces.md)

## M9: Window thumbnail (exploratory)
Spec: [features/window-thumbnail.md](features/window-thumbnail.md). It ships only if it can be done without private APIs and the Screen Recording permission prompt is acceptable to users.
