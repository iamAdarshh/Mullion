# CLAUDE.md

Guidance for Claude Code in this repository. Keep this file short. Detailed docs live in `docs/` and are linked below.

## What this is
**Mullion** is a free, open-source macOS window manager written in Swift. v1 provides Magnet-style snapping (keyboard, drag-to-edge, menu bar, multi-display). v2 adds PowerToys-style Zones, Grab & Move, App memory and Workspaces.
- Architecture (always loaded): @docs/ARCHITECTURE.md
- Current plan (always loaded): @docs/ROADMAP.md
- Product spec (read when working on behaviour): `docs/PRD.md`
- Feature specs: `docs/features/*.md` · Decisions: `docs/adr/*.md` · Shortcuts: `docs/SHORTCUTS.md`

## The owner
Adarsh is an experienced .NET/React/TypeScript developer who is **new to Swift and AppKit**. When you introduce a Swift or macOS concept for the first time (actors, `@MainActor`, CF types, AX, run loops, `@Observable`), add a one-line explanation in your reply, comparing it to C#/.NET where that helps. Don't over-explain general programming.

## Commands
```bash
make bootstrap    # xcodegen generate – run after changing project.yml or pulling
make build        # debug build of the app
make test-core    # FAST: swift test on Packages/MullionCore – run after every Core change
make test         # core + app tests
make lint         # swiftlint + swiftformat --lint (CI fails on any warning)
make format       # apply swiftformat
make run          # build + launch Mullion-Debug.app (needs the human for permission prompts)
```
- After editing Swift: run `make test-core` (Core) or `make build` (App) before saying you're done.
- Don't run `make run` on your own if the user isn't watching. Launching the app can show system permission prompts.

## Architecture rules (non-negotiable)
1. **Geometry lives in `Packages/MullionCore`.** No `import AppKit` or `import ApplicationServices` there. It is pure Foundation + CoreGraphics and fully unit-tested. If you're computing a rect in the App target, move it to Core.
2. **Core works in AX coordinates** (top-left origin of the primary screen). Convert only via `CoordinateSpace`. Never write `screenHeight - y` anywhere else.
3. **All AX calls go through `AXQueue` / `AXWindow`.** No raw `AXUIElementSetAttributeValue` in feature code. Every AX call handles `AXError`. No force-unwraps. `as!` on a CF value is allowed only immediately after a `CFGetTypeID` check (pattern in the `macos-window-apis` skill).
4. **Public APIs only** ([ADR-0003](docs/adr/0003-public-apis-only.md)). No private symbols, `dlopen`, `@_silgen_name`, SkyLight/CGS, or asking users to disable SIP.
5. **No network calls** in v1. Nothing that phones home.
6. **Swift 6 strict concurrency.** UI on `@MainActor`, AX work on `AXQueue`. `@unchecked Sendable` only with a comment explaining why it's safe.
7. **No new dependencies** without an ADR update ([ADR-0005](docs/adr/0005-dependencies.md)). Only stable, released versions, pinned exactly.

## Code style
- SwiftFormat and SwiftLint configs are at the repo root; a hook formats edited Swift files automatically.
- Types are `UpperCamelCase`; one primary type per file, named after the file.
- Prefer `struct` + `enum` and value semantics. Use `final class` only for AppKit subclasses and stateful services.
- Errors: typed `enum ...Error: Error`, and log them with `Logger(subsystem:category:)`. Never `print`.
- User-facing strings go in `Localizable.xcstrings` (String Catalog). No hard-coded UI strings.
- Public Core APIs get `///` doc comments.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) with parameterised fixtures from `Fixtures/Screens.swift`.

## Workflow
- **Spec first.** Don't implement a v2 feature without its `docs/features/*.md` spec marked *Accepted*. For anything non-obvious, write a short plan and get a 👍 before coding.
- **Small steps.** One roadmap checkbox per commit where possible. Tick the checkbox in `docs/ROADMAP.md` in the same commit.
- **Test first for Core.** Add a failing test, make it pass, then refactor. Bug fixes always come with a regression test.
- **Keep docs in sync.** If behaviour changes, update the PRD, the feature spec, `SHORTCUTS.md` and `CHANGELOG.md` (*Unreleased*) in the same PR.
- **Branches:** `feat/<milestone>-<slug>`, `fix/<slug>`, `docs/<slug>`. Never commit directly to `main` once CI exists.
- **Commits:** Conventional Commits (`feat(core): add sixths actions`, `fix(ax): clamp min-size windows`). Scopes: `core`, `ax`, `input`, `overlay`, `menu`, `settings`, `zones`, `workspaces`, `build`, `docs`, `ci`.
- Before opening a PR, run `/review-branch`, which uses the `mullion-reviewer` subagent and `REVIEW.md`.

## Things you can't do from here: ask the human
Granting Accessibility or Screen Recording, clicking in System Settings, physically dragging windows, plugging in displays, and signing with an Apple Developer certificate. When a step needs the human, say exactly what to do and what to report back.

## Gotchas (read before touching the related code)
- `NSScreen.main` ≠ the primary screen. Use `NSScreen.screens.first` for coordinate conversion.
- The Accessibility grant is lost when the debug build's signature changes → see `docs/SETUP.md#troubleshooting`.
- Set size → position → size when moving windows across displays (see ARCHITECTURE §5).
- Some apps need `AXEnhancedUserInterface` turned off temporarily to resize correctly.
- macOS 15+ has its own edge-drag tiling that conflicts with ours. Detect it, never change it.
