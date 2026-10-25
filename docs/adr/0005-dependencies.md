# ADR-0005: Dependency policy

- **Status:** Accepted
- **Date:** 2026-10-19

## Policy
1. Prefer Apple frameworks. Every third-party dependency needs a line in the table below and a reason.
2. Licences must be MIT, BSD, Apache-2.0 or ISC. No GPL, because Mullion is MIT.
3. Pin to an exact released version in `project.yml` / `Package.swift`. No branch pins and no prerelease versions.
4. MullionCore has **zero** third-party dependencies.

## Approved
| Package | Pin | Licence | Used for | Why not build it |
|---|---|---|---|---|
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 3.1.0 (exact) | MIT | Global hotkeys, the recorder UI, and storing shortcuts | Carbon hotkey plumbing plus a good recorder UI is weeks of work, and this package is mature and widely used |
| [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle) | 2.10.0 (exact) | MIT | Opt-in update checks and installing updates in place (v1.1, [ADR-0008](0008-in-app-updates-with-sparkle.md)) | Safe in-place updates (EdDSA verification, replacing a running app, relaunch, admin authorisation) are hard to get right; Sparkle is the standard for apps outside the App Store |

**KeyboardShortcuts 3.1.0** (pinned 2026-10-19, M1): chosen over 2.4.0 for its macOS 27 compatibility fixes and the fix for a release-build crash with the Swift 6.3 compiler. It needs Swift tools 6.2, so CI runs on the `macos-26` runner image (Xcode 26).

## Candidates (need an ADR when adopted)
| Package | For | Notes |
|---|---|---|
| swift-snapshot-testing | Settings UI snapshots | Dev-only |
