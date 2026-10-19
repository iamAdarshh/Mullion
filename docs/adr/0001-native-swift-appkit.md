# ADR-0001: Native Swift with AppKit and SwiftUI

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
A window manager runs all the time, reacts to every mouse drag, and has to feel instant. It needs the Accessibility APIs, event monitors and borderless overlay panels, all of which are AppKit- and CoreFoundation-level APIs.

## Options considered
1. **Swift + AppKit, with SwiftUI for settings.** First-class API access, small memory footprint, and the same approach Rectangle and Magnet take.
2. **Hammerspoon (Lua) config.** Very fast to prototype, but it isn't a standalone app, and it's hard to ship a polished UI or distribute.
3. **Electron or Tauri.** Big memory footprint for a background utility. The AX calls would need native bridges anyway.
4. **.NET MAUI / Avalonia** (the author's main stack). Mac support for these low-level APIs is thin, and every call would be P/Invoke into ApplicationServices.

## Decision
Option 1. Use the **Swift 6 language mode** with strict concurrency checking, **AppKit** for the app shell, menu bar, panels and event plumbing, and **SwiftUI** for the Settings, onboarding and editor chrome. The minimum OS is **macOS 14 Sonoma** (for `@Observable`, the modern `SettingsLink`, and `SMAppService`).

## Consequences
- Native performance and full API access.
- The author learns Swift and AppKit, which is a deliberate learning goal for this project.
- Users on macOS 13 or older are not supported.
