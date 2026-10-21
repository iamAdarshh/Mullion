# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Mullion's own app icon and menu bar icon: a window split by a mullion, its left pane snapped.
- Drag to snap: drag a window by its title bar into a screen edge, a corner, a bottom third or, on ultrawide displays, a top sixth, and a translucent preview in your accent colour shows where it will go, gaps included. Release to snap it there, on the display the preview was on. The preview slides between areas (with Reduce motion on, it jumps).
- *Restore* after a drag snap puts the window back where it was before the drag, or before Mullion first snapped it.
- Dragging a snapped window away and dropping it outside every snap area gives it back its size from before the snap.
- Hold ⌥ while dragging to move a window without snapping.
- *Ignore “App”* in the menu stops the frontmost app's windows from snapping when dragged; shortcuts still work on them.
- On macOS 15 and later, if macOS's own window tiling is on (edge tiling, or “Hold ⌥ key while dragging windows to tile”), Mullion explains the conflict once per launch, with buttons to open Desktop & Dock settings or not show the notice again.
- *Settings…* (⌘,) opens the Settings window. **General**: what repeating a half shortcut does, the gap between windows, the Almost Maximize size, the Grow and Shrink step, and whether dragging a snapped window away restores its size. Changes apply immediately.
- Launch at login (Settings → General), managed by macOS, so it also shows in System Settings → General → Login Items.
- The menu bar icon can be hidden in Settings → General. Opening Mullion again while it's running opens Settings. If Accessibility access goes missing, the icon comes back with its warning.
- **Settings → Drag**: turn drag to snap off (dragging a snapped window away still restores its size), use ⌃ instead of ⌥ to move a window without snapping, change the size of the edge and corner areas, pick the preview's colour and opacity, and turn off the haptic tap on Force Touch trackpads. It also warns, for as long as it applies, when macOS's own tiling is on.
- **Settings → Shortcuts**: change the shortcut for any action, including the sixths, which have none by default. A shortcut another action already uses is refused, and *Restore Defaults…* puts them all back.
- **Settings → Ignored Apps**: see and edit the apps whose windows never snap when dragged, adding running apps or any app from the Applications folder.
- **Settings → Advanced**: export your settings, shortcuts and ignored apps to `mullion-config.json`, and import them on another Mac. Import replaces everything; files from a newer Mullion are refused.
- **Settings → Advanced** also has *Reset Everything…*, *Copy Diagnostics* (a summary for bug reports that doesn't name your ignored apps) and *Open Console*.
- **Settings → About** shows the version, licence and acknowledgements, and links to the source code. *About Mullion* in the menu opens it.

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
