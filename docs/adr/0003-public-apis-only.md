# ADR-0003: Public APIs only

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
Several attractive features are only possible with private frameworks (SkyLight / CGS*), private AX functions (`_AXUIElementGetWindow`), or disabling SIP. Examples: always-on-top for other apps' windows, moving windows between Spaces, and instant window lookup by `CGWindowID`.

## Decision
Mullion uses **only public, documented APIs**. That means no `dlsym` tricks, no private symbols, and no instructions asking users to disable SIP.

## Consequences
- Fewer things break across macOS updates, there's no risk of being blocked, and contributors can rely on Apple's documentation.
- Non-goals: always-on-top, Spaces control, interactive crop (re-hosting windows).
- Windows are identified by `AXUIElement` equality (`CFEqual`) within a session, and by bundle ID + title + order heuristics across sessions.
- **Review rule:** any PR that introduces a private symbol, `dlopen`, or a `@_silgen_name` binding to a system function is rejected. See [REVIEW.md](../../REVIEW.md).
- An exception requires a new ADR that supersedes this one.
