# ADR-0005: Dependency policy

- **Status:** Accepted
- **Date:** 2026-10-19

## Policy
1. Prefer Apple frameworks. Every third-party dependency needs a line in the table below and a reason.
2. Licences must be MIT, BSD, Apache-2.0 or ISC. No GPL, because Mullion is MIT.
3. Pin to an exact released version in `project.yml` / `Package.swift`. No branch pins and no prerelease versions.
4. MullionCore has **zero** third-party dependencies.

## Approved
| Package | Licence | Used for | Why not build it |
|---|---|---|---|
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | MIT | Global hotkeys, the recorder UI, and storing shortcuts | Carbon hotkey plumbing plus a good recorder UI is weeks of work, and this package is mature and widely used |

## Candidates (need an ADR when adopted)
| Package | For | Notes |
|---|---|---|
| Sparkle | Auto-update | Introduces network access, so it must be opt-in |
| swift-snapshot-testing | Settings UI snapshots | Dev-only |
