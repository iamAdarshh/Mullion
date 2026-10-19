# Feature spec: Grab & Move

**Milestone:** M6. **Status:** Draft. **Inspired by:** PowerToys Grab And Move, and Easy Move+Resize on macOS

## Summary
Hold a modifier (default **⌃⌘**) and left-drag *anywhere* inside a window to move it. Hold the modifier and right-drag to resize it from the nearest corner. There's no need to find the title bar.

## Behaviour
| Input | Effect |
|---|---|
| modifier + left-drag | Move the window under the cursor (it doesn't have to be focused) |
| modifier + right-drag | Resize from the corner nearest to where the drag started |
| modifier + left-drag + ⇧ | Move and show zones (works with the Zones feature) |
| modifier + left-drag to a snap area | Same as a normal drag-to-snap |

- Option: *Bring window to front when grabbed* (default on).
- Option: *Modifier* can be ⌃⌘, ⌥⌘, ⌃⌥, or fn⌃.
- Ignored apps and full-screen windows are passed through untouched.

## Implementation notes
- This needs an **active** `CGEventTap` (`.cgSessionEventTap`, `.headInsertEventTap`, not listen-only), because the mouse-down, drag and up events must be **swallowed** so the app under the cursor doesn't receive the click. Active taps require the Accessibility permission, which Mullion already has.
- The tap callback must return in microseconds. Do the AX work on a dedicated serial queue and throttle `setFrame` to the display refresh rate (CADisplayLink or a 60–120 Hz timer).
- Find the window via `AXUIElementCopyElementAtPosition(systemWide, x, y)`, then walk up `kAXParentAttribute` until `kAXRole == kAXWindowRole`.
- Handle `kCGEventTapDisabledByTimeout` and `kCGEventTapDisabledByUserInput` by re-enabling the tap and logging a warning.
- Only swallow events while the modifier is held at mouse-down. Never swallow events otherwise.

## Acceptance criteria
- G-1: With the modifier released, no click is ever swallowed. Verify with a manual test in Finder, Safari, Terminal and VS Code.
- G-2: Moving tracks the cursor with no visible lag at 120 Hz on a ProMotion display.
- G-3: If the tap is disabled by the system, it is re-enabled within 1 s.
