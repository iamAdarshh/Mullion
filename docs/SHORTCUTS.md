# Default keyboard shortcuts

Every shortcut can be remapped in **Settings → Shortcuts**. The defaults use the **⌃⌥** (Control + Option) prefix, which macOS and most apps leave free.

**Without Accessibility access** the shortcuts are released, so other apps receive those keys. They come back within 5 s of access being granted again, or at once when you open the menu (PRD §6.9.3).

**Conflicts to avoid.** macOS 15+ uses **fn ⌃ + arrows** and **fn ⌃ ⇧ + arrows** for its own tiling, and **⌃ + arrows** for Mission Control and switching Spaces. Mullion's defaults use none of these.

## v1

| Action | Default | Notes |
|---|---|---|
| Left Half | ⌃⌥ ← | Repeat to cycle ½ → ⅔ → ⅓ |
| Right Half | ⌃⌥ → | Repeat to cycle |
| Top Half | ⌃⌥ ↑ | |
| Bottom Half | ⌃⌥ ↓ | |
| Top Left | ⌃⌥ U | |
| Top Right | ⌃⌥ I | |
| Bottom Left | ⌃⌥ J | |
| Bottom Right | ⌃⌥ K | |
| First Third | ⌃⌥ D | |
| Center Third | ⌃⌥ F | |
| Last Third | ⌃⌥ G | |
| First Two-Thirds | ⌃⌥ E | |
| Last Two-Thirds | ⌃⌥ T | |
| Sixths (×6) | *unassigned* | Available in the menu and Settings |
| Maximize | ⌃⌥ ↩ | |
| Almost Maximize | ⌃⌥ ⇧ ↩ | |
| Maximize Height | ⌃⌥ ⇧ ↑ | |
| Center | ⌃⌥ C | |
| Restore | ⌃⌥ ⌫ | |
| Grow / Shrink | ⌃⌥ = / ⌃⌥ - | |
| Next Display | ⌃⌥⌘ → | |
| Previous Display | ⌃⌥⌘ ← | |

## v2

| Action | Default | Notes |
|---|---|---|
| Open Zone Editor | ⌃⌥⌘ ` | |
| Switch to layout 1–9 | ⌃⌥⌘ 1…9 | Applies to the display under the cursor |
| Move window to next / previous zone | ⌃⌥⇧ → / ⌃⌥⇧ ← | Zone navigation, FancyZones style |
| Show Workspaces palette | ⌃⌥ W | |
| Grab & Move (mouse) | hold ⌃⌘ + drag | Configurable modifier |
| Grab & Resize (mouse) | hold ⌃⌘ + right-drag | Resizes from the nearest corner |
| Snap to zone while dragging | hold ⇧ while dragging | Add ⌘ to span several zones |
| Disable snapping while dragging | hold ⌥ while dragging | |

## Rules for adding a new default
1. Check it against the macOS system shortcuts (*System Settings → Keyboard → Keyboard Shortcuts*) and against VS Code, Xcode, JetBrains IDEs, Chrome, Safari and Slack.
2. Add it to this table **and** to `DefaultShortcuts.swift` in the same PR.
3. If in doubt, leave it unassigned. Users can bind it themselves.
