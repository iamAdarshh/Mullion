# Feature spec: Zones

**Milestones:** M4 (core) and M5 (editor). **Status:** Draft. **Inspired by:** PowerToys FancyZones

## Summary
Users define their own layouts made of zones (rectangles). While dragging a window with ⇧ held, the zones of the display under the cursor appear, and dropping the window resizes it to fill the zone under the cursor. Zones are what make Mullion more than a Magnet clone.

## User stories
1. As an ultrawide user, I want a 25 / 50 / 25 column layout so that my code sits in the middle with docs and a terminal on either side.
2. As a multi-monitor user, I want a different layout on each display so that my vertical monitor stacks windows top to bottom.
3. As a keyboard user, I want to move the focused window to the next zone, and switch layouts, without using the mouse.
4. As someone who switches tasks often, I want 2–3 saved layouts per display and a hotkey to switch between them.

## Data model (`MullionCore/Zones`)
```swift
struct ZoneLayout: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var kind: Kind            // .columns, .rows, .grid, .priorityGrid, .canvas
    var zones: [Zone]         // ordered; index = zone number shown in UI
    var spacing: CGFloat      // pt between zones; independent from v1 gap
    var schemaVersion: Int = 1
}

struct Zone: Codable, Hashable {
    var rect: UnitRect        // x,y,w,h in 0…1 of visibleFrame, origin top-left
}

struct DisplayLayoutAssignment: Codable {
    var displayUUID: String   // CGDisplayCreateUUIDFromDisplayID
    var activeLayoutID: UUID
    var quickSwitch: [UUID]   // index 0…8 → ⌃⌥⌘1…9
}
```
- Storage: `~/Library/Application Support/Mullion/layouts.json` and `assignments.json`, written atomically. If a file can't be decoded, back it up as `*.corrupt-<date>.json` and fall back to the defaults. Never crash on bad JSON.
- Templates generate a `ZoneLayout`. Once the user edits one in the editor it becomes a `.canvas` or a custom grid.

## Behaviour
### Dragging into zones
- Holding ⇧ (configurable) at any point during a window drag shows the zone overlay on the display under the cursor. Releasing ⇧ hides it.
- The zone under the cursor is highlighted. **⇧⌘** while hovering extends the selection across every zone between the first highlighted zone and the current one (their bounding union).
- Option: *Show zones on all displays while dragging* (default off).
- When zones are showing, the v1 snap areas are suspended for that drag.

### Keyboard
- `moveToNextZone` / `moveToPreviousZone` move the focused window along the layout's zone order. At the last zone, the window wraps around to the first zone of the next display (configurable).
- `switchLayout(n)` switches the active layout on the display under the cursor. A small HUD shows the layout name for 0.8 s.
- *Option:* When the layout switches, move windows that were in zone *k* to zone *k* of the new layout (FancyZones calls this "windows keep their zone number").

### Display changes
- Observe `NSApplication.didChangeScreenParametersNotification`. Look up assignments by display UUID. A display Mullion hasn't seen before gets the default layout (2 columns for landscape, 2 rows for portrait).
- Option: *Keep windows in their zones when resolution changes* (default on).

## Editor (M5)
- Opened via the menu, Settings, or ⌃⌥⌘\`. It covers the display under the cursor with a dimmed full-screen panel.
- **Grid mode:** click a zone to split it horizontally, ⌥-click to split it vertically, drag a divider to resize, and drag a divider onto another divider to merge the zones.
- **Canvas mode:** add, move and resize free rectangles. Zones may overlap.
- A toolbar holds the name field, spacing stepper, template picker, *Save*, *Cancel*, and *Apply to display*.
- Keyboard: Tab cycles zones, arrow keys nudge the selected divider by 1 % (⇧ for 5 %), and ⌫ deletes the selected zone.

## Edge cases
- Apps with a minimum size bigger than the zone: place at the zone's origin and log it. Don't fight the app.
- A zone smaller than 100×100 pt is not allowed in the editor.
- Stage Manager is on: zones are computed from `visibleFrame` as normal, and the Stage Manager strip is not accounted for. Document this as a known limitation.

## Acceptance criteria
- Z-1: Template generation and spanning union are unit-tested, along with zone hit-testing at boundaries (the hysteresis rule is the same as for v1 snap areas).
- Z-2: Layouts survive an app restart and unplugging and replugging a display.
- Z-3: Corrupt JSON is backed up and the app still launches.
- Z-4: The overlay draws in under 16 ms on a 5K display.

## Open questions
- Should a layout be per Space as well as per display? There is no public Spaces API, so this is deferred.
