# Contributing to Mullion

Thanks for helping! Mullion is a small project with a solo maintainer, so these guidelines keep things moving.

## Before you start
- **Bugs:** open an issue using the *Bug report* template. Include your macOS version, display setup, and the app affected.
- **Features:** open a *Feature request* first. Anything non-trivial needs a spec in `docs/features/` (see the template structure in `.claude/skills/write-spec/SKILL.md`) before code is written.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), especially §4 on coordinate systems, and the [ADRs](docs/adr/).

## Hard rules
1. **Public macOS APIs only.** PRs using private frameworks or symbols are closed ([ADR-0003](docs/adr/0003-public-apis-only.md)).
2. **No telemetry, and no network access** beyond the opt-in Sparkle update check and download ([ADR-0008](docs/adr/0008-in-app-updates-with-sparkle.md)).
3. **Geometry goes in `MullionCore`, with tests.**
4. **No GPL code**, including code copied or adapted from GPL projects. Mullion is MIT.
5. New dependencies need an ADR update ([ADR-0005](docs/adr/0005-dependencies.md)).

## Development
See [docs/SETUP.md](docs/SETUP.md). In short: `brew install xcodegen swiftlint swiftformat jq`, then `make bootstrap test`.

## Pull requests
- Branch from `main`: `feat/…`, `fix/…`, `docs/…`.
- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat(zones): add priority grid template`.
- Keep PRs small and focused, ideally under 400 changed lines.
- `make lint test` must pass, and CI must be green.
- Update `CHANGELOG.md` under *Unreleased* for any user-visible change.
- Fill in the PR template, including the manual-test rows you ran.
- Reviews follow [REVIEW.md](REVIEW.md).

## Using AI assistants
This repo ships a Claude Code setup (`CLAUDE.md`, `.claude/`). AI-assisted PRs are welcome. You are responsible for every line you submit: you should understand it, have tested it, and be able to explain it in review.

## Code of conduct
Be kind, assume good intent, and keep discussion technical. Harassment of any kind isn't tolerated. Report problems privately to the maintainer via GitHub.
