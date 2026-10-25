# Testing

## Layers
| Layer | Tool | Command | Runs in CI |
|---|---|---|---|
| MullionCore unit tests | Swift Testing (`import Testing`) | `make test-core` (`swift test --package-path Packages/MullionCore`) | ✅ |
| App logic tests (with fakes) | Swift Testing via `xcodebuild test` | `make test-app` | ✅ |
| App logic tests on macOS 15 | The same tests, built on macOS 26 and run with `xcodebuild test-without-building` | `make build-for-testing`, then `make test-without-building XCTESTRUN=…` | ✅ (`older-macos` job) |
| Lint and format | SwiftLint, SwiftFormat (`--lint`) | `make lint` | ✅ |
| Manual matrix | A human (or Claude, following the `manual-test` skill) | see below | ❌ |

`make test` runs core and app tests. CI can't run the app tests on macOS 14 (the current Swift Testing won't load there), so macOS 14 relies on the manual matrix.

## Unit-test conventions
- One test file per source file: `ActionCalculator.swift` → `ActionCalculatorTests.swift`.
- Use **parameterised tests** (`@Test(arguments:)`) for geometry. Every action × every screen fixture.
- Shared screen fixtures live in `Tests/MullionCoreTests/Fixtures/Screens.swift`:
  - `macBookAir13` (1470×956 @2x, menu bar 37 pt notch)
  - `studioDisplay` (2560×1440 @2x)
  - `ultrawide` (3440×1440 @1x)
  - `portrait1080` (1080×1920 @1x)
  - Arrangements: `laptopLeftOfExternal`, `externalAbovePrimary`, `portraitRightOfPrimary`, `threeDisplays`
- Assert rects with `#expect(rect.isApproximatelyEqual(to: expected, tolerance: 0.5))`.
- No sleeps in tests. Inject a `Clock` for time-based logic (cycle timeout, hysteresis).
- Every bug fix starts with a failing test that reproduces it.

## App-level fakes
```swift
protocol WindowControlling: Sendable {
    func focusedWindow(pid: pid_t) async throws -> WindowRef?
    func frame(of: WindowRef) async throws -> CGRect
    func setFrame(_: CGRect, of: WindowRef, sizeBeforeMove: CGSize?) async throws
    func isAlive(_: WindowRef) async -> Bool
}
@MainActor protocol ScreenProviding { var screens: [ScreenGeometry] { get } }
```
There is no public AX attribute for a window's minimum size, so the dispatcher sets the frame, reads it back, and re-anchors it when the app kept a different size. `FakeWindowController` records calls (with the size asked for before each move) and can simulate minimum sizes, fixed-size windows, closed windows and AX errors. The write sequence itself is tested in `AXWindowTests` against a simulated window that cuts a resize short at the screen edge and can then drop the next one, as #16 suggests.

## Manual test matrix
Run the rows for the milestone being closed. Record the results in the milestone's tracking issue.

### Setups
| ID | Setup |
|---|---|
| S1 | MacBook alone (notch) |
| S2 | MacBook + 1 external, external to the right |
| S3 | MacBook + 1 external placed **above** |
| S4 | MacBook + portrait external |
| S5 | Ultrawide (real or BetterDisplay virtual 3440×1440) |
| S6 | Dock auto-hide on, Dock on the left |
| S7 | Stage Manager on |

### Apps
Finder, Safari, Chrome, Terminal, VS Code (Electron), Xcode, Slack (Electron), System Settings (fixed-size), Calculator (non-resizable), Preview, Microsoft Teams or Zoom (if available).

### Cases
| # | Case | Milestone | Setups |
|---|---|---|---|
| 1 | Every v1 shortcut on a focused Safari window | M1 | S1, S2 |
| 2 | Repeat ⌃⌥← three times, which cycles ½ → ⅔ → ⅓ | M1 | S1 |
| 3 | Restore after snapping | M1 | S1 |
| 4 | Snap System Settings / Calculator (min or fixed size) and check it stays on the same screen without jumping | M1 | S1, S2 |
| 5 | Next / previous display keeps the snapped action | M1 | S2, S3, S4 |
| 6 | No window focused (Finder desktop click) and a shortcut: nothing happens, no beep | M1 | S1 |
| 7 | Drag to each edge and corner, check the preview and the snap | M2 | S1, S2, S3 |
| 8 | Hover on a corner/edge boundary: no flicker | M2 | S1 |
| 9 | Bottom-edge slide gives two-thirds | M2 | S1, S5 |
| 10 | Ultrawide top sixths | M2 | S5 |
| 11 | ⌥ while dragging: no snap | M2 | S1 |
| 12 | Ignored app: no snap | M2 | S1 |
| 13 | Drag a snapped window away: original size restored under the cursor | M2 | S1 |
| 14 | Sequoia tiling enabled: the notice appears exactly once | M2 | S1 |
| 15 | Selecting text in a window by dragging must **not** trigger a preview | M2 | S1 |
| 16 | Revoke Accessibility while running: warning badge, actions disabled, no crash | M0 | S1 |
| 17 | Launch at login works after a reboot | M3 | S1 |
| 18 | Export, reset, import: identical settings | M3 | S1 |
| 19 | VoiceOver can operate every Settings control | M3 | S1 |
| 20 | Dock moved or auto-hidden: snaps respect the new visible frame without a relaunch | M1 | S6 |

### Performance checks (M3)
- Instruments *Time Profiler*: average snap under 50 ms (signpost `Mullion.snap`).
- Activity Monitor: idle CPU 0.0 %, memory under 40 MB after 10 minutes idle.
