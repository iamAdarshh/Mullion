---
name: manual-test
description: Walk the user through Mullion's manual test matrix for a milestone and record pass/fail results. Use before closing a milestone or a release, or when the user says "let's test M2".
argument-hint: "[milestone, e.g. M1]"
disable-model-invocation: true
---

# Manual test session: $ARGUMENTS

Claude can't move the mouse or see the screen in this workflow, so the human runs each step and Claude guides them and records the results.

1. Read `docs/TESTING.md` and pick every case tagged **$ARGUMENTS**, plus the setups (S1–S7) it lists.
2. Ask which setups the user has available right now (displays, Stage Manager, and so on). Skip the others and mark them *not run*. Don't mark them passed.
3. Make sure the latest build is running (`/build-and-run`).
4. Go **one case at a time**: give the exact steps (keys to press, where to drag) and what to expect, then wait for "pass" or "fail + what happened".
5. On a fail: collect the details (app, display setup, what happened instead), ask for the `log stream` output if it's useful, and write it up as a bug, but **keep testing**. Don't start fixing mid-session unless the user asks.
6. At the end, print a results table (case, setup, result, notes) and:
   - If `gh` is authenticated, offer to post it as a comment on the milestone's tracking issue and to open one issue per failure, with the label `bug` and milestone $ARGUMENTS.
   - Otherwise, append it to `docs/test-runs/$ARGUMENTS-<date>.md`.
