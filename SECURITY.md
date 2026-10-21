# Security and privacy

## What Mullion can access
Mullion needs the macOS **Accessibility** permission. That permission is powerful: it lets an app read and control the UI of other apps. Mullion uses it only to:
- read the position, size, title, role and subrole of windows
- set the position and size of windows
- observe mouse drags (and, if you turn on Grab & Move, intercept modifier+drag)

Mullion does **not** read window contents, keystrokes, text fields, or the clipboard.

The optional Window Thumbnail feature (if it ships) would need **Screen Recording**, and it is requested only when you first use that feature.

## Data
- Settings live in `UserDefaults` and `~/Library/Application Support/Mullion/`.
- Mullion doesn't read window titles today. The planned Workspaces feature (v2) will store titles only for workspaces you save, as matching hints, and will never log them above `debug` level.
- **No network connections.** There is no telemetry, no analytics and no crash upload. If an update checker is ever added, it will be opt-in and documented here.

## Verifying a build
Releases are built by GitHub Actions (`.github/workflows/release.yml`) from the tagged commit, with `make archive dmg` (see [docs/RELEASING.md](docs/RELEASING.md)). Each GitHub Release lists the SHA-256 of its files in `checksums.txt`:
```bash
shasum -a 256 Mullion-X.Y.Z.dmg
```

## Reporting a vulnerability
Please **don't** open a public issue. Use GitHub's private vulnerability reporting (*Security → Report a vulnerability* on the repository). You should get a response within 7 days.
