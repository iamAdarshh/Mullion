# ADR-0002: Distribute outside the Mac App Store

- **Status:** Accepted
- **Date:** 2026-10-19

## Context
App Store apps must be sandboxed. The App Sandbox blocks a lot of what Mullion needs: controlling other apps via Accessibility, active event taps (Grab & Move), and launching arbitrary apps with arguments (Workspaces).

## Decision
- Ship **non-sandboxed** with the **Hardened Runtime** enabled.
- Distribute through GitHub Releases (a DMG) and a Homebrew cask.
- Until there's a paid Apple Developer account, releases are **ad-hoc signed** and documented as such (users right-click the app and choose Open, or run `xattr -dr com.apple.quarantine`). Once a Developer ID is available, releases are **notarized**.

## Consequences
- The full feature set is possible.
- No App Store discovery or automatic updates. Add Sparkle (opt-in update checks) later, which needs its own ADR because it introduces network access.
- Unsigned builds show a Gatekeeper warning, which is a barrier for non-technical users.
