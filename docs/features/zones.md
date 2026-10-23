# Feature spec: Zones

**Milestones:** M4 (core) and M5 (editor). **Status:** Accepted (M4; the Editor section is reviewed again before M5). **Inspired by:** PowerToys FancyZones

## Summary
Users define their own layouts made of zones (rectangles), one active layout per display. While dragging a window with ⇧ held, the zones of the display under the cursor appear, and dropping the window resizes it to fill the zone under the cursor; adding ⌘ spans several zones. Zones sit alongside the v1 snap areas: a plain drag works exactly as in v1. In M4 layouts come from templates set up in Settings → Zones; M5 adds a visual editor.

## User stories
1. As an ultrawide user, I want a 25 / 50 / 25 column layout so that my code sits in the middle with docs and a terminal on either side.
2. As a multi-monitor user, I want a different layout on each display so that my vertical monitor stacks windows top to bottom.
3. As a keyboard user, I want to move the focused window to the next zone, and switch layouts, without using the mouse.
4. As someone who switches tasks often, I want 2–3 saved layouts per display and a hotkey to switch between them.
5. As a v1 user, I want my edge snapping to keep working exactly as before, so that trying zones costs me nothing.

## Data model (`MullionCore/Zones`)
```swift
/// A named set of zones. Layouts are shared; displays refer to them by `id`.
public struct ZoneLayout: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var template: ZoneTemplate?   // nil once the M5 editor has changed the zones (a custom layout)
    public var zones: [Zone]             // ordered; index + 1 = the zone number shown in the overlay
    public var spacing: CGFloat          // 0…40 pt, default 8; replaces the v1 gap for zone placements
}

public struct Zone: Codable, Hashable, Sendable {
    public var rect: UnitRect            // fractions of visibleFrame, origin top-left (AX), before spacing
}

/// How a template layout is generated. Percentages are whole numbers, each ≥ 10, summing to 100.
public enum ZoneTemplate: Codable, Hashable, Sendable {
    case columns(percentages: [Int])            // 1…6 columns, left to right
    case rows(percentages: [Int])               // 1…6 rows, top to bottom
    case grid(rows: [Int], columns: [Int])      // 1…4 each; zones numbered row by row
    case priorityGrid(zoneCount: Int)           // 3…5, see below
}

public struct DisplayZoneAssignment: Codable, Hashable, Sendable {
    public var displayUUID: String       // CGDisplayCreateUUIDFromDisplayID
    public var activeLayoutID: UUID
    public var quickSwitch: [UUID?]      // 9 slots → ⌃⌥⌘1…9; slot 1 starts as the first active layout
}

// On disk, each file has an envelope with a top-level schemaVersion (ARCHITECTURE §8).
struct LayoutsFile: Codable { var schemaVersion = 1; var layouts: [ZoneLayout] }
struct AssignmentsFile: Codable { var schemaVersion = 1; var assignments: [DisplayZoneAssignment] }
```
- `zones` is always the source of truth for hit-testing and placement. When `template` is set, Core regenerates `zones` from it, so the Settings tab can show and edit the template's parameters. `UnitRect` gains `Codable`.
- **Priority grid** (centre-weighted, for wide displays): 3 zones = columns 25 / 50 / 25; 4 zones = the same, with the right column split into two rows; 5 zones = both side columns split into two rows. Zones are numbered left column first, top to bottom, then the centre, then the right column.
- **Storage:** `~/Library/Application Support/Mullion/layouts.json` and `assignments.json`, written atomically. A file that can't be decoded is renamed to `*.corrupt-YYYYMMDD-HHMMSS.json`, the defaults are loaded, and the user sees a notice once. Never crash on bad JSON. This store is new; v1 has no JSON files yet.
- **Preferences** (`UserDefaults` through `Preferences`): *Zones enabled* (on), *Show zones on all displays while dragging* (off), *Next zone wraps to the next display* (on), *Keep windows in their zones when displays change* (on).
- **Export/import:** `mullion-config.json` gets schema version 2 with a `zones` section holding the preferences, layouts and assignments. `ConfigMigrator` upgrades a version 1 file by adding the defaults, so v1.0 exports still import.

## Behaviour
### Defaults
- A display Mullion hasn't seen before gets a layout chosen by shape, created on first sight and stored: **portrait** → 2 rows, **wider than 2.1 : 1** (ultrawide) → priority grid with 3 zones, **otherwise** → 2 columns.

### Dragging into zones
| Input during a window drag | Effect |
|---|---|
| plain drag | v1 snap areas, unchanged (PRD §6.4) |
| hold ⇧ | Zones of the display under the cursor appear; v1 snap areas are suspended while ⇧ is held |
| ⇧ + cursor over a zone | That zone is highlighted |
| ⇧⌘ | Spanning: the zone highlighted when ⌘ went down is the anchor; every zone intersecting the bounding rect of the anchor and the current zone is highlighted |
| release ⌘ (⇧ still held) | Back to a single zone |
| release ⇧ | Zones hide, v1 snap areas come back |
| drop with zones showing | The window fills the highlighted zone, or the bounding rect of the spanned zones, with the layout's spacing applied |
| ⌥ or ⌃ held (with or without ⇧) | All snapping off for the drag, as in v1 |
| app on the ignore list | No zones, as in v1 |

- The modifier is fixed at ⇧ in M4. ⌥ and ⌃ already disable snapping, and ⌘ is the span key.
- **Hit-testing:** the zone containing the cursor wins; where zones overlap (M5 canvas), the smallest one wins. In the spacing between zones, or outside every zone, the nearest zone wins, so there are no dead areas. Hysteresis is the v1 rule: the cursor has to be `DragSettings.hysteresis` (8 pt) past a zone's edge before it counts as having left.
- **Spacing:** applied like the v1 gap (`Gaps.apply`): full spacing at the screen edges, half on edges shared with another zone, so neighbours end up exactly `spacing` apart.
- **Overlay:** the existing per-screen overlay panels draw every zone's outline with its number, and fill the highlighted zones with the drag preview colour. Reduced motion: it fades in and out, no frame animation.
- *Show zones on all displays while dragging* (off): when on, every display shows its zones; only the display under the cursor highlights.
- **Restore** (⌃⌥⌫) and dragging a zoned window away behave as for v1 snaps: the window gets back its frame from before the first Mullion placement.

### Keyboard
| Action | Default | Effect |
|---|---|---|
| Move window to next zone | ⌃⌥⇧ → | The focused window moves to the next zone of its display's active layout |
| Move window to previous zone | ⌃⌥⇧ ← | The same, backwards |
| Switch to layout 1…9 | ⌃⌥⌘ 1…9 | The display under the cursor activates the layout in that quick-switch slot |

- **Current zone:** the zone whose spaced rect matches the window's frame within 2 pt. For a spanned window, *next* goes to the zone after the last spanned zone and *previous* to the one before the first. A window in no zone goes to zone 1 (*next*) or the last zone (*previous*).
- **Wrapping:** past the last zone the window moves to zone 1 of the next display (`DisplayNavigator` order, that display's active layout). With *Next zone wraps to the next display* off, or with one display, it wraps to zone 1 of the same display.
- **Switching layouts** shows a HUD with the layout name for 0.8 s on that display. An empty slot shows "No layout in slot *n*" instead. Windows already placed stay where they are.

### Display changes
- Observe `NSApplication.didChangeScreenParametersNotification` (debounced 0.5 s). Assignments are looked up by display UUID; a display returns to its layout when it is plugged back in.
- *Keep windows in their zones when displays change* (on): windows Mullion placed in a zone this session are re-fitted to the same zone numbers when their display's resolution, arrangement or visible frame changes, as long as the window is still where Mullion put it (within 2 pt). A window the user has moved since, or whose display is gone, is left alone.

### Settings → Zones tab (M4)
- **Displays:** one row per connected display (its name) with the active layout picker and the nine quick-switch slots.
- **Layouts:** a list with *Add*, *Duplicate*, *Rename* and *Delete*. For the selected layout: template picker (columns, rows, grid, priority grid), count steppers, one percentage field per column or row, a spacing stepper, and a live miniature of the zones with their numbers.
- **Preview on display:** shows the layout's zone overlay on the display under the settings window for 2 s.
- **Validation:** the layout can't be saved while percentages don't sum to 100 or one is below 10; the fields say why. A preview zone smaller than 100 × 100 pt on the smallest connected display gets a warning, not a block.
- The three preferences above, and a *Zones enabled* switch that turns off ⇧-drag and the zone hotkeys.
- Every control has a VoiceOver label; every string is in `Localizable.xcstrings`.

### Out of scope for M4
- The visual editor and canvas layouts (M5, below).
- *Windows keep their zone number when the layout switches* (moving every window from zone *k* to zone *k* of the new layout). Deferred: it needs every zoned window tracked across apps and layouts. Not scheduled.
- A configurable drag modifier; per-Space layouts (no public Spaces API).

## Editor (M5)
*Reviewed again before M5 starts; accepting this spec for M4 doesn't accept this section.*
- Opened via the menu, Settings, or ⌃⌥⌘\`. It covers the display under the cursor with a dimmed full-screen panel.
- **Grid mode:** click a zone to split it horizontally, ⌥-click to split it vertically, drag a divider to resize, and drag a divider onto another divider to merge the zones.
- **Canvas mode:** add, move and resize free rectangles. Zones may overlap.
- A toolbar holds the name field, spacing stepper, template picker, *Save*, *Cancel*, and *Apply to display*.
- Keyboard: Tab cycles zones, arrow keys nudge the selected divider by 1 % (⇧ for 5 %), and ⌫ deletes the selected zone.
- Saving an edited template layout sets `template` to nil.

## Implementation notes
- **Public APIs only** (ADR-0003): `NSEvent` flags from the existing passive monitor (`.flagsChanged`, ADR-0006), `CGDisplayCreateUUIDFromDisplayID`, AX frame writes through `AXQueue`/`AXWindow`, `NSPanel` overlays. No new permission, no new dependency, no network.
- **Core** (`MullionCore/Zones`, pure and unit-tested): `ZoneTemplate` → zones generation and validation, `ZoneLayout.rects(in:)` with spacing, `ZoneResolver` (hit-testing, hysteresis, spanning), `ZoneNavigator` (current zone, next/previous, wrapping across displays), default-layout choice by display shape, and the JSON envelopes with migration.
- **App:** `DragMonitor` adds ⇧/⌘ state to the drag and routes to `ZoneResolver` instead of `SnapAreaResolver` while ⇧ is held. Drops go through the existing `ActionDispatcher` drop path (window lookup by frame, `RestoreStore`), with a zone rect instead of an action. `ZoneStore` (`@MainActor`) loads and saves the JSON files. Placements are recorded in memory only (`WindowRef` + display UUID + layout ID + zone numbers + placed frame), never persisted, because AX elements change across launches.
- The drag window is still read from the window server during the drag and looked up over AX at the drop (ARCHITECTURE §6).
- **Signposts:** `Mullion.zoneOverlay` around each overlay redraw; zone drops and zone hotkeys reuse `Mullion.snap`.

## Edge cases
- Apps with a minimum size bigger than the zone: place at the zone's origin and clamp inside the visible frame, as for v1 snaps (ARCHITECTURE §5). Don't fight the app.
- A layout in use is deleted: displays using it, and quick-switch slots pointing at it, fall back to the default layout for their shape.
- Two identical monitors that report the same display UUID share one assignment. Logged; known limitation.
- A display's layout was set up on a much larger screen and a zone becomes tiny: still applied; the Settings warning covers it.
- Stage Manager on: zones are computed from `visibleFrame` as normal, and the Stage Manager strip is not accounted for. Known limitation.
- Full-screen windows and Mullion's own windows are never moved, as in v1.

## Acceptance criteria
- **Z-1:** Template generation (every template, percentages, counts at their limits) and validation are unit-tested, including the priority grid layouts and spacing via `Gaps.apply`.
- **Z-2:** Zone hit-testing is unit-tested at zone edges, in the spacing, outside all zones, with overlapping zones and with hysteresis; spanning is unit-tested for adjacent, diagonal and non-adjacent zones.
- **Z-3:** On S3 + S5, a ⇧-drag shows the zones of the display under the cursor, and the drop fills the highlighted zone within 2 pt. A plain drag still uses the v1 snap areas, and ⌥ disables both.
- **Z-4:** ⇧⌘-drag across three columns of a 25 / 50 / 25 layout places the window across all three.
- **Z-5:** ⌃⌥⇧→ / ← walk a window through every zone and wrap to the next display, or to zone 1 with wrapping off. ⌃⌥⌘1…9 switch layouts with the HUD.
- **Z-6:** Layouts and assignments survive an app restart and unplugging and replugging a display; a new display gets the default for its shape.
- **Z-7:** With *Keep windows in their zones* on, changing a display's resolution re-fits the windows placed in its zones.
- **Z-8:** A corrupt `layouts.json` or `assignments.json` is backed up, the app launches with defaults, and the notice shows once.
- **Z-9:** Export → reset → import restores the zone layouts, assignments and preferences; a v1.0 export still imports.
- **Z-10:** ⌃⌥⌫ after a zone placement restores the earlier frame.
- **Z-11:** Overlay redraws take under 16 ms (`Mullion.zoneOverlay`, p95) on the ultrawide and the built-in Retina display; zone placements meet NFR-1 (p95 < 50 ms).
- **Z-12:** The `M4` rows added to the [manual test matrix](../TESTING.md#manual-test-matrix) pass on S1 and S3 + S5, and every Settings → Zones control is operable with VoiceOver.

## Open questions
- Should a layout be per Space as well as per display? There is no public Spaces API, so this is deferred.
- *Windows keep their zone number when the layout switches*: deferred (see Out of scope). Revisit after M5.
