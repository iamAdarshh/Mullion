# Feature spec: Workspaces

**Milestone:** M8. **Status:** Draft. **Inspired by:** PowerToys Workspaces

## Summary
A workspace is a saved set of apps and their window positions across displays. Launching it opens any apps that aren't running and arranges their windows, so a single click goes from an empty desktop to a ready-to-work setup.

## User stories
1. As a developer, I want a "Coding" workspace (Xcode on the left ⅔, Simulator on the right ⅓, Terminal on the external display) so that I can start work in one click.
2. As a student, I want a "Thesis" workspace (PDF reader, editor, browser) that I can launch from the menu bar.

## Behaviour
### Capture
- *Menu → Workspaces → Capture current layout…* lists every visible standard window grouped by display. Each window has a checkbox, all checked by default.
- For each checked window, Mullion stores: bundle ID, app path, window title (used only as a matching hint), display UUID, and frame normalised to that display's visible frame. If the window fits a zone or action exactly, it stores that zone or action ID instead.
- The user names the workspace and can optionally assign a hotkey.

### Launch
1. For each app: if it isn't running, `NSWorkspace.shared.openApplication(at:configuration:)`.
2. Wait for windows using an `AXObserver` (`kAXWindowCreatedNotification`) with a timeout per app (default 10 s).
3. Match saved entries to windows: same bundle ID, then title similarity, then creation order.
4. Place each window. If its display is missing, fall back to the main display and keep the relative position.
5. Show a HUD with progress and any failures (for example, "Slack: no window after 10 s").
- Option: *Minimise other windows* (default off).
- Option: *Launch at login* (one workspace only).

### Edit
Settings → Workspaces offers rename, delete, reorder, remove apps, change an app's target zone or action, add launch arguments, and *Launch & recapture*.

## Storage
`~/Library/Application Support/Mullion/workspaces.json`, versioned, written atomically.

## Limitations
- Mullion can't restore documents, tabs or app state, only windows.
- Apps that open several windows on launch are matched on a best-effort basis.
- Apps that are slow to launch (Electron apps, IDEs) may need a longer timeout, which is configurable per app.

## Acceptance criteria
- W-1: A three-app workspace on two displays launches from cold and is arranged within 15 s.
- W-2: If one app fails, the others are still placed, and the HUD reports the failure.
- W-3: Launching a workspace while its apps are already running only rearranges them.
