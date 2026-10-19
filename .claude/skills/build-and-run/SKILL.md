---
name: build-and-run
description: Regenerate the Xcode project, build Mullion, and launch the debug app, diagnosing common build, signing and Accessibility-permission problems. Use when the user wants to try the app or a build fails.
allowed-tools: Bash(make bootstrap) Bash(make build) Bash(xcodebuild *) Bash(xcodegen *) Bash(log show *)
---

# Build and run Mullion (debug)

1. `make bootstrap`. If `xcodegen` is missing, tell the user to run `brew install xcodegen`.
2. `make build`. On failure:
   - Read the **first** error, not the last. Swift errors cascade.
   - `No such module 'KeyboardShortcuts'` → run `xcodebuild -resolvePackageDependencies -project Mullion.xcodeproj`, then rebuild.
   - Signing errors → check `Config/Local.xcconfig` (copy it from `Local.xcconfig.example`) and that `DEVELOPMENT_TEAM` is set, or that ad-hoc signing (`CODE_SIGN_IDENTITY = -`) is in use.
   - Swift 6 concurrency errors → fix them properly (actor isolation or `Sendable`). Never silence them with `nonisolated(unsafe)` unless you explain why in a comment.
3. Ask the user before running `make run` (it launches a GUI app and may show permission prompts).
4. After launch, tell the user what to check:
   - The Mullion icon appears in the menu bar
   - If it's the first run: grant **Mullion Debug** in *System Settings → Privacy & Security → Accessibility*
5. If the user says "nothing happens" or "the permission is on but it doesn't work":
   - Ask them to run `log stream --predicate 'subsystem BEGINSWITH "io.github.iamadarshh.mullion"' --level debug` and paste the output
   - The likely cause is a changed code signature. Point them to `docs/SETUP.md#troubleshooting`. **Don't** run `tccutil` yourself; it's denied in settings and is the user's call.
