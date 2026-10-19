---
name: write-adr
description: Record an architecture decision record (ADR) in docs/adr/. Use when choosing between technical approaches, adding a dependency, changing a platform constraint, or superseding an earlier decision.
argument-hint: "[decision title]"
---

# Write ADR: $ARGUMENTS

1. List `docs/adr/` and take the next number (4 digits, zero-padded).
2. Copy the structure from `docs/adr/0000-template.md`.
3. List at least 2 real options, each with concrete pros and cons for *this* project (a macOS menu bar app, public APIs only, MIT licence, a solo maintainer learning Swift).
4. Leave **Status: Proposed** until the user agrees, then set it to **Accepted** with today's date.
5. If it supersedes an older ADR, set the old one's status to `Superseded by ADR-NNNN` and link both ways.
6. Update every doc that references the decision (the ARCHITECTURE §3 table, CLAUDE.md rules, ADR-0005 for dependencies).
7. Commit with `docs(adr): NNNN <title>`.
