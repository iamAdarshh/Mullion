# ADR-0006: Drag detection with a passive NSEvent monitor; an active CGEventTap only for Grab & Move

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
Drag-to-snap needs to observe mouse drags system-wide but never block them. Grab & Move (v2) has to *swallow* clicks while the modifier is held.

## Options considered
1. **`NSEvent.addGlobalMonitorForEvents`.** Passive and simple. Can't modify or swallow events. Delivered on the main thread.
2. **Listen-only `CGEventTap`.** Passive, slightly lower level, and can run on its own run loop.
3. **Active `CGEventTap`.** Can swallow events. A slow or crashed callback can make the whole system's input feel laggy, and macOS disables taps that time out.
4. **Polling `CGWindowList`.** Wasteful and laggy.

## Decision
- **M2 drag-to-snap:** option 1. Mouse-moved and drag events are cheap, and the passive monitor can't break anyone's input.
- **M6 Grab & Move:** option 3, isolated in `GrabTap`, running on its own thread with its own run loop. It is enabled only while the feature is on, and it re-enables itself on `tapDisabledByTimeout`.
- If option 1 turns out to be too slow on high-refresh displays, switch drag-to-snap to option 2 and record that in a new ADR.

## Update (2026-10-20): reading the dragged window
While a window is dragged by its title bar, its app is busy in the drag loop and doesn't answer Accessibility requests, so every AX frame read during the drag timed out (`kAXErrorCannotComplete`). During the drag Mullion therefore reads the window's position from the window server with `CGWindowListCopyWindowInfo`, which answers without asking the app. This is not option 4: the list is read once when the drag starts and then only for that one window, on mouse events, until it is seen to move. The AX element is looked up once at the drop. Only window number, owner pid, layer and bounds are read, so no Screen Recording permission is needed.

At the drop there is no public way to turn the window number into an AX element, so the dragged app's main window is tried first (a title-bar drag makes it main, and a hidden native tab can share its frame), then its other standard windows, matched to the window-server bounds within 2 pt. If none matches, the main window is still taken when it has the same size and is within 30 pt, because some apps nudge their window after a drop; a main window elsewhere on screen is never taken. A timeout stops the search and it is retried once after 50 ms.

The monitor also watches `.flagsChanged`, so ⌥ takes effect while the mouse is still, and a timer checks every 0.25 s during a window drag that the button is still held, because a release can be missed (for example in Mission Control). It cancels only after two checks in a row, because the button state changes before the release event is delivered.

## Consequences
- v1 can never swallow a user's click.
- Two input paths to maintain. Both feed the same `SnapAreaResolver`.
