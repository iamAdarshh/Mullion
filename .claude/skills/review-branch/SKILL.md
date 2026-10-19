---
name: review-branch
description: Review the current branch's changes against REVIEW.md and CLAUDE.md using the mullion-reviewer subagent, then summarise findings by severity. Use before opening a PR or when the user asks for a review.
allowed-tools: Bash(git diff *) Bash(git log *) Bash(git status *)
---

# Review the current branch

## Changes
!`git log --oneline main..HEAD 2>/dev/null || git log --oneline -10`

!`git diff --stat main...HEAD 2>/dev/null || git diff --stat HEAD`

## Steps
1. If there are no changes compared with `main`, say so and stop.
2. Delegate to the **mullion-reviewer** subagent with the instruction: "Review `git diff main...HEAD` against REVIEW.md and CLAUDE.md. Return findings with file:line, severity, and a suggested fix."
3. Present the findings grouped as 🔴 Important, 🟡 Nit (at most 5), then ✅ checklist items that passed.
4. Offer to fix the 🔴 findings. Don't fix Nits unless asked.
