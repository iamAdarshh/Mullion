---
name: add-window-action
description: Add a new window snapping action (for example "left fourth" or "top two-thirds") to Mullion end to end, covering the Core enum and math, parameterised tests, default shortcut, menu item, and docs. Use when the user asks for a new snap position or size.
argument-hint: "[action name and geometry, e.g. 'leftFourth = left 25%']"
---

# Add window action: $ARGUMENTS

A new action touches every layer below, in this order. Don't skip a step. REVIEW.md checks for all of them.

1. **Define it.** Confirm the exact geometry with the user if it's ambiguous: fraction of the visible frame, landscape *and* portrait behaviour, and whether it takes part in repeat-to-cycle.
2. **Core enum.** Add a case to `Packages/MullionCore/Sources/MullionCore/Actions/WindowAction.swift`, in its group (halves, quarters, thirds, sixths, other, display). Give it a stable `rawValue` string, because it's persisted in configs.
3. **Test first.** In `ActionCalculatorTests.swift`, add expected rects for every fixture in `Fixtures/Screens.swift` (at minimum `macBookAir13`, `ultrawide`, `portrait1080`, plus a non-primary display above the primary), with and without gaps. Run `make test-core` and watch it fail.
4. **Math.** Implement it in `ActionCalculator`. Use `UnitRect` fractions; don't hand-compute pixels. Run `make test-core` until green.
5. **Shortcut.** Add a `KeyboardShortcuts.Name` in `App/Sources/Input/DefaultShortcuts.swift`. A default key is optional; follow the rules in `docs/SHORTCUTS.md` and leave it unassigned if unsure.
6. **Menu.** Add the item to its group in `MenuBarController`, with a localised title in `Localizable.xcstrings`.
7. **Drag (optional).** If it should have a snap area, add it to `SnapAreaResolver` defaults with tests, and update PRD §6.4.
8. **Docs.** Update the PRD §6.1 table, `docs/SHORTCUTS.md`, and `CHANGELOG.md` (*Unreleased → Added*).
9. `make build && make lint`, then commit `feat(core): add <action> action`.
