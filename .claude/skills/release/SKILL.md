---
name: release
description: Run Mullion's release checklist for a version (changelog, version bump, archive, sign/notarize, DMG, tag, GitHub release, Homebrew cask).
argument-hint: "[version, e.g. 1.0.0]"
disable-model-invocation: true
---

# Release v$ARGUMENTS

Follow `docs/RELEASING.md` exactly, ticking each step in chat as you go.

Rules:
- Only stable versions are released (`X.Y.Z`). A `-beta.N` version gets a GitHub prerelease and **no** Homebrew cask update.
- Stop before any step that publishes or signs (`git tag`, `git push`, `gh release`, `codesign`, `notarytool`). Show the exact command and wait for the user's yes. These commands are in the `ask` list in settings.
- If `make lint test` fails, stop. Never release a red build.
- Generate the release notes from `CHANGELOG.md`, using the template in RELEASING.md. Include the unsigned-build note if no Developer ID was used.
- Afterwards, add a fresh `## [Unreleased]` section to `CHANGELOG.md`.
