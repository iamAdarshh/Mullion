---
name: write-spec
description: Write or update a feature spec in docs/features/ before any implementation. Use when the user proposes a new feature or wants to flesh out one of the v2 specs.
argument-hint: "[feature name]"
---

# Write a feature spec for: $ARGUMENTS

1. Check `docs/features/` for an existing spec. If one exists, update it rather than creating a new one.
2. Interview the user briefly, one question at a time, no more than 5 questions in total: the problem, who it's for, the must-have behaviour, what's out of scope, and how we'll know it works.
3. Check feasibility against the constraints. Read ADR-0003 (public APIs only) and ADR-0006 (input). If the feature needs a private API or SIP changes, say so clearly and propose the closest public-API version.
4. Create `docs/features/<kebab-name>.md` with this structure:
   - Title + `**Milestone:** … · **Status:** Draft · **Inspired by:** …`
   - Summary (2–3 sentences)
   - User stories ("As a …, I want … so that …")
   - Data model (Swift types, if any are persisted, with `schemaVersion`)
   - Behaviour (inputs → effects table, options with defaults)
   - Implementation notes (which macOS APIs, threads/actors, permissions)
   - Edge cases
   - Acceptance criteria (IDs like `XX-1`, each one testable)
   - Open questions
5. Link it from the PRD §7 table and give it a milestone in `docs/ROADMAP.md`.
6. Status stays **Draft** until the user explicitly approves it, then set it to **Accepted**.
