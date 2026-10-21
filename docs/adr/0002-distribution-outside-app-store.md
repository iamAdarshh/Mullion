# ADR-0002: Distribute outside the Mac App Store

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
App Store apps must be sandboxed. The App Sandbox blocks a lot of what Mullion needs: controlling other apps via Accessibility, active event taps (Grab & Move), and launching arbitrary apps with arguments (Workspaces).

## Decision
- Ship **non-sandboxed** with the **Hardened Runtime** enabled.
- Distribute through GitHub Releases (a DMG) and a Homebrew cask.
- Until there's a paid Apple Developer account, releases are **ad-hoc signed** and documented as such (users click *Open Anyway* in System Settings → Privacy & Security, or run `xattr -dr com.apple.quarantine`; macOS 15 and later no longer let right-click → Open past Gatekeeper). Once a Developer ID is available, releases are **notarized**.
- **Update (M3, 2026-10-21):** v1.x ships without a Developer ID. The Homebrew cask lives in our own tap only, because `homebrew/cask` requires apps that pass Gatekeeper. See [RELEASING.md](../RELEASING.md), checklist step 6.

## Consequences
- The full feature set is possible.
- No App Store discovery or automatic updates. Add Sparkle (opt-in update checks) later, which needs its own ADR because it introduces network access.
- Unsigned builds show a Gatekeeper warning, which is a barrier for non-technical users.
