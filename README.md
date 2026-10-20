# Mullion

> A free, open-source window manager for macOS. Snap windows with the keyboard or by dragging, design your own zone layouts, and launch whole workspaces in one click.

*A mullion is the bar that divides a window into panes. This app does the same for your screen.*

> **Status: pre-alpha, planning stage.** Nothing is built yet. This repository currently holds the product spec, the architecture, and the Claude Code starter kit used to build it. See [docs/ROADMAP.md](docs/ROADMAP.md).

---

## Features

### v1: Snapping essentials
- **Keyboard snapping:** halves, quarters, thirds, two-thirds, sixths, maximize, almost-maximize, center, and restore
- **Cycle on repeat:** press *Left Half* again to get ⅔, then ⅓
- **Drag to snap:** drag a window to an edge or corner, see a live preview, and release to snap it
- **Multi-display:** send a window to the next or previous display, keeping its relative position. Vertical screens are supported.
- **Gaps:** optional spacing between snapped windows
- **Menu bar app:** every action is available from the menu, so no shortcuts need to be memorised
- **Settings:** remappable shortcuts, launch at login, a per-app ignore list, and import/export of your configuration

### v2: Beyond Magnet (inspired by PowerToys)
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
Mullion has no releases yet. To build from source, see [docs/SETUP.md](docs/SETUP.md).

```bash
brew install xcodegen swiftlint swiftformat
git clone https://github.com/iamAdarshh/mullion.git
cd mullion
make bootstrap   # generates Mullion.xcodeproj
make run         # builds and launches the app
```

On first launch, Mullion asks for the Accessibility permission (*System Settings → Privacy & Security → Accessibility*).

### Using macOS Sequoia or later?
macOS 15+ has built-in window tiling. When you drag a window to a screen edge, both Mullion and macOS respond. Mullion detects this and offers to open *System Settings → Desktop & Dock → Windows*, where you can turn off **Drag windows to screen edges to tile** and **Drag windows to menu bar to fill screen**. If **Hold ⌥ key while dragging windows to tile** is on, holding ⌥ tiles the window with macOS instead of turning Mullion's snapping off, so Mullion mentions that too. Mullion never changes your system settings itself.

## Privacy
Mullion runs fully offline. It reads window positions and titles only to arrange windows, and it stores your settings locally in `~/Library/Application Support/Mullion/` and `UserDefaults`. See [SECURITY.md](SECURITY.md).

## Contributing
Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). This repo is set up for [Claude Code](https://code.claude.com/docs/en/overview): see [CLAUDE.md](CLAUDE.md) and `.claude/`.

## Acknowledgements
Mullion is an original, independent project. It is inspired by the ideas behind [Magnet](https://magnet.crowdcafe.com), [Microsoft PowerToys FancyZones & Workspaces](https://learn.microsoft.com/windows/powertoys/), and [Rectangle](https://github.com/rxhanson/Rectangle). It is not affiliated with any of them and contains none of their code or assets.

## License
[MIT](LICENSE) © 2026 Adarsh Choudhary
