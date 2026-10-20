# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Drag to snap: drag a window by its title bar into a screen edge, a corner, a bottom third or, on ultrawide displays, a top sixth, and a translucent preview in your accent colour shows where it will go, gaps included. Release to snap it there, on the display the preview was on. The preview slides between areas (with Reduce motion on, it jumps).
- *Restore* after a drag snap puts the window back where it was before the drag, or before Mullion first snapped it.
- Dragging a snapped window away and dropping it outside every snap area gives it back its size from before the snap.
- Hold ⌥ while dragging to move a window without snapping.
- *Ignore “App”* in the menu stops the frontmost app's windows from snapping when dragged; shortcuts still work on them.
- On macOS 15 and later, if macOS's own window tiling is on (edge tiling, or “Hold ⌥ key while dragging windows to tile”), Mullion explains the conflict once per launch, with buttons to open Desktop & Dock settings or not show the notice again.

## [0.1.0-beta.1] - 2026-10-19

### Added
- Project starter kit: product spec, architecture, roadmap, ADRs, feature specs, and the Claude Code setup.
- Mullion runs as a menu bar app with a placeholder menu (*Settings…*, *Quit Mullion*).
- A welcome window explains why Accessibility access is needed and continues automatically once it's granted.
- If Accessibility access is revoked while Mullion is running, the menu bar icon shows a warning and the menu offers *Grant Accessibility access…*. Mullion's shortcuts are released until access is back, so other apps receive those keys.
- Keyboard snapping: halves, quarters, thirds, two-thirds, sixths, maximize, almost maximize, maximize height, center, grow, shrink and restore, with the default ⌃⌥ shortcuts from SHORTCUTS.md.
- Repeating a half shortcut cycles the window through ½, ⅔ and ⅓ of the screen.
- Move to next / previous display keeps a snapped window's position (for example, left half) on the new display.
- Windows from apps with a minimum or fixed size stay on the target display instead of spilling off it.
- The menu bar lists every action, grouped, with its shortcut. Actions are disabled while Accessibility access is missing.
