---
name: kickoff
description: Plan and implement one roadmap milestone (M0–M9) of Mullion step by step. Use when the user says "start M1", "kick off the next milestone", or "/kickoff M2".
argument-hint: "[milestone, e.g. M0]"
disable-model-invocation: true
---

# Kick off milestone $ARGUMENTS

## 1. Load context
- Read `docs/ROADMAP.md` and find milestone **$ARGUMENTS**. If no argument was given, pick the first milestone with unticked boxes and confirm it with the user.
- Check that the previous milestone is done (every box ticked). If it isn't, stop and tell the user what's left.
- Read the PRD sections and feature spec referenced by this milestone, and any ADRs they link to.
- For v2 milestones: the spec in `docs/features/` must have **Status: Accepted**. If it says *Draft*, run through its open questions with the user first, then update the status.

## 2. Plan (wait for approval)
Write a short plan in chat:
- The milestone's checkboxes, each mapped to 1–3 concrete tasks, with the files to create or change
- The order (Core and tests first, then the App wiring, then UI)
- What the human must do (permissions, manual checks) and when
- Risks or unknowns, plus anything that needs a new ADR

Ask: "OK to proceed?" Don't write code before a yes.

## 3. Build in small loops
For each task:
1. Create a branch `feat/$ARGUMENTS-<slug>` if you're not already on one for this milestone.
2. Core logic: write the failing Swift Testing test → implement → `make test-core`.
3. App wiring: implement → `make build`.
4. `make lint`. Fix any warnings.
5. Tick the roadmap checkbox, update `CHANGELOG.md` *Unreleased* if the change is user-visible, and commit with a Conventional Commit message.
6. Give a one-line progress note in chat. When a concept is new to a .NET developer, explain it in one line.

Stop and ask whenever you hit something the spec doesn't cover. Don't invent product behaviour.

## 4. Close
- Run `/manual-test $ARGUMENTS` with the user, or list the matrix rows for them to run.
- Run `/review-branch` and fix all 🔴 findings.
- Summarise what shipped, what was deferred (opening issues for it if `gh` is available), and the next milestone.
