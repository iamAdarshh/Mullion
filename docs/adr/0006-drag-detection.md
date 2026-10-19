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

## Consequences
- v1 can never swallow a user's click.
- Two input paths to maintain. Both feed the same `SnapAreaResolver`.
