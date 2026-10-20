# Mullion

[![CI](https://github.com/iamAdarshh/Mullion/actions/workflows/ci.yml/badge.svg)](https://github.com/iamAdarshh/Mullion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey)

**Snap any window into halves, thirds, quarters or sixths, from the keyboard or by dragging it to a screen edge.** Mullion is a free, open-source window manager for macOS, written in Swift. It lives in the menu bar, uses only public macOS APIs, and never connects to the internet.

*A mullion is the bar that divides a window into panes. This app does the same for your screen.*

<!-- TODO: demo GIF (drag to snap + ⌃⌥← cycling), ~800 px wide: ![Mullion demo](docs/images/demo.gif) -->

> **Status: beta.** Keyboard snapping and drag to snap work today. Settings, launch at login and the first stable release (v1.0) come next. Custom zones and workspaces follow in v2. See the [roadmap](docs/ROADMAP.md).

---

## Features

✅ available in the beta · 🛠️ next (v1.0) · 🗺️ planned (v2)

### v1: Snapping essentials
- ✅ **Keyboard snapping:** halves, quarters, thirds, two-thirds, sixths, maximize, almost maximize, maximize height, center, grow, shrink and restore
- ✅ **Cycle on repeat:** press ⌃⌥← again to go from ½ to ⅔, then ⅓
- ✅ **Drag to snap:** drag a window to an edge, corner or bottom third, see a live preview in your accent colour, and let go to snap it. Slide along the bottom edge for two-thirds; ultrawide screens get top sixths. Hold ⌥ to drag without snapping.
- ✅ **Drag away to unsnap:** a snapped window you drag off gets its original size back
- ✅ **Multi-display:** send a window to the next or previous display; a snapped window keeps its position (left half stays left half). Displays placed beside, above or below each other are supported.
- ✅ **Menu bar:** every action with its shortcut, plus *Ignore “App”* to stop an app's windows from snapping when dragged
- ✅ **Works with apps that have a minimum or fixed size:** the window stays on the target display instead of spilling off it
- 🛠️ **Settings window:** remap shortcuts, gaps between windows, launch at login, ignore list, import/export

| Default shortcut | Action |
|---|---|
| ⌃⌥ ← → ↑ ↓ | Left / right / top / bottom half |
| ⌃⌥ U I J K | Quarters |
| ⌃⌥ D F G · E T | Thirds · two-thirds |
| ⌃⌥ ↩ · ⌃⌥ C · ⌃⌥ ⌫ | Maximize · center · restore |
| ⌃⌥⌘ ← → | Previous / next display |

All of them are in [docs/SHORTCUTS.md](docs/SHORTCUTS.md).

### v2: Beyond Magnet (inspired by PowerToys) 🗺️
- **Zones:** design custom layouts (columns, grids, priority grid, or freeform), hold ⇧ while dragging to drop a window into a zone, span several zones, use one layout per display, and switch layouts with a hotkey
- **Grab & Move:** hold ⌃⌘ and drag anywhere inside a window to move it; right-drag to resize it
- **App memory:** an app reopens in the zone where you last placed it (opt-in per app)
- **Workspaces:** save a set of apps and their positions, then launch and arrange them all from the menu bar

See [docs/PRD.md](docs/PRD.md) for the full specification and [docs/SHORTCUTS.md](docs/SHORTCUTS.md) for the default key map.

### What Mullion will *not* do
- **Always-on-top / pinning other apps' windows:** macOS has no public API for this, and Mullion uses no private APIs.
- **Automatic BSP tiling:** if you want an i3-style tiler, use [AeroSpace](https://github.com/nikitabobko/AeroSpace) or [yabai](https://github.com/koekeishiya/yabai).
- **Telemetry:** Mullion makes no network calls (an opt-in update check may be added later).

## Requirements
- macOS 14 Sonoma or later (Apple silicon and Intel)
- The **Accessibility** permission, which is required to move other apps' windows

## Install
### Download the beta
1. Download the latest `Mullion-*.dmg` from [Releases](https://github.com/iamAdarshh/Mullion/releases) and drag Mullion to Applications.
2. Beta builds aren't notarized yet, so macOS blocks the first launch. Open it anyway from *System Settings → Privacy & Security* (scroll to *Security*, click **Open Anyway**), or run `xattr -dr com.apple.quarantine /Applications/Mullion.app`.
3. Grant the **Accessibility** permission when Mullion asks.

After installing a new beta, you may need to turn Mullion's Accessibility permission off and on again: unsigned builds look like a different app to macOS after every update.

### Build from source
Needs Xcode 26 or later (Swift 6.2). Full instructions are in [docs/SETUP.md](docs/SETUP.md).

```bash
brew install xcodegen swiftlint swiftformat
git clone https://github.com/iamAdarshh/Mullion.git
cd Mullion
make bootstrap   # generates Mullion.xcodeproj
make run         # builds and launches the app
```

On first launch, Mullion asks for the Accessibility permission (*System Settings → Privacy & Security → Accessibility*).

### Using macOS Sequoia or later?
macOS 15+ has built-in window tiling. When you drag a window to a screen edge, both Mullion and macOS respond. Mullion detects this and offers to open *System Settings → Desktop & Dock → Windows*, where you can turn off **Drag windows to screen edges to tile** and **Drag windows to menu bar to fill screen**. If **Hold ⌥ key while dragging windows to tile** is on, holding ⌥ tiles the window with macOS instead of turning Mullion's snapping off, so Mullion mentions that too. Mullion never changes your system settings itself.

## Privacy
Mullion runs fully offline. It reads only the position, size and type of windows, never their titles or contents, and stores its settings locally in `UserDefaults`. See [SECURITY.md](SECURITY.md).

## Contributing
Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). This repo is set up for [Claude Code](https://code.claude.com/docs/en/overview): see [CLAUDE.md](CLAUDE.md) and `.claude/`.

## Acknowledgements
Mullion is an original, independent project. It is inspired by the ideas behind [Magnet](https://magnet.crowdcafe.com), [Microsoft PowerToys FancyZones & Workspaces](https://learn.microsoft.com/windows/powertoys/), and [Rectangle](https://github.com/rxhanson/Rectangle). It is not affiliated with any of them and contains none of their code or assets.

## License
[MIT](LICENSE) © 2026 Adarsh Choudhary
