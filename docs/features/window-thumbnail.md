# Feature spec: Window thumbnail (exploratory)

**Milestone:** M9. **Status:** Exploratory, not committed. **Inspired by:** PowerToys Crop And Lock (thumbnail mode)

## Idea
Pick a window, optionally crop a region of it, and get a small, always-floating, **view-only** live copy of it. Examples: a build log, a video call, or a dashboard tucked into a corner.

## Why only "thumbnail" mode
PowerToys also has a "reparent" mode where the cropped window stays interactive. macOS has no public way to re-host another app's window, so that mode is out of scope ([ADR-0003](../adr/0003-public-apis-only.md)).

## Approach
- `ScreenCaptureKit`: build an `SCContentFilter(desktopIndependentWindow:)` for the chosen window and an `SCStream` at 15–30 fps, and render it into a borderless `NSPanel` at `.floating` level. It is Mullion's own window, so it can float.
- Requires the **Screen Recording** permission, which is a second, scarier prompt. It is only requested when the user first uses this feature.
- Clicking the thumbnail focuses the original window.

## Go / no-go questions
1. Is the CPU and battery cost acceptable (target under 3 % CPU at 15 fps)?
2. Does the periodic Screen Recording re-approval prompt on macOS 15+ make the feature annoying?
3. Do users actually want it? Gauge with a GitHub Discussion poll after v2.0.
