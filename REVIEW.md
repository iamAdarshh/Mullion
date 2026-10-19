# Review instructions

This file is used by Claude Code Review on pull requests, by the local `mullion-reviewer` subagent (`/review-branch`), and by human reviewers. General project rules live in `CLAUDE.md`, and violating one of them counts as a finding.

## What 🔴 Important means here
Reserve **Important** for findings that would:
- **Break window placement:** wrong rect math, AppKit/AX coordinate mix-ups, ignoring the visible frame, a window landing on the wrong display.
- **Crash or hang the app or the user's input:** force-unwraps on AX/CF values, `as!` on a CF value without a preceding `CFGetTypeID` check, blocking AX calls on the main thread, an event-tap callback doing heavy work, a missing `tapDisabledByTimeout` handling.
- **Swallow user input unexpectedly:** any path where a click or key reaches Mullion and isn't passed on when it should be.
- **Violate trust:** private APIs ([ADR-0003](docs/adr/0003-public-apis-only.md)), network calls, logging window titles or contents at default/info level, writing to other apps' or the system's preferences.
- **Lose user data:** non-atomic config writes, a schema change without a migration, deleting a corrupt file instead of backing it up.
- **Data races:** Swift 6 concurrency violations, an `@unchecked Sendable` with no justification comment.

Style, naming, and refactoring suggestions are 🟡 **Nit** at most.

## Always check
- [ ] Any new or changed geometry is in `Packages/MullionCore` and has parameterised tests across the screen fixtures, including a non-primary display above or left of the primary and a portrait display.
- [ ] AppKit ↔ AX conversion happens only in `CoordinateSpace`.
- [ ] Every `AXUIElement*` call's `AXError` is handled, and AX work runs on `AXQueue`, not `@MainActor`.
- [ ] A new action is wired end to end: `WindowAction` case, calculator, default shortcut (or deliberately unassigned), menu item, `docs/SHORTCUTS.md`, PRD table, and tests.
- [ ] A new default shortcut doesn't clash with macOS system shortcuts (fn⌃ arrows, ⌃ arrows) or common apps. See the rules in `docs/SHORTCUTS.md`.
- [ ] User-facing strings are in the String Catalog, and Settings controls have accessibility labels.
- [ ] Persisted models have `schemaVersion`, and a version bump comes with a `Migrator` step and a test that decodes the old JSON.
- [ ] New dependencies are listed in ADR-0005 with their licence and pinned exactly to a stable release.
- [ ] `CHANGELOG.md` (*Unreleased*) is updated for user-visible changes, and the roadmap checkbox is ticked.
- [ ] Behaviour claims in findings cite `file:line`. Don't infer behaviour from names.

## Cap the nits
Report at most **5** Nits per review. Prefer the ones a newcomer to Swift would learn the most from.

## Do not report
- Anything CI enforces: SwiftLint, SwiftFormat, compiler warnings, test failures.
- The generated `Mullion.xcodeproj`, `*.xcstrings` key ordering, `Package.resolved`, asset catalogs.
- Docs-only PRs: report only factual errors and broken links.
- `docs/features/*` marked *Exploratory*: report only factual errors.

## Higher bar
- `Makefile`, `scripts/`, `.github/workflows/`: report only if the problem is near-certain and would break CI or releases.
