# Releasing

Versioning follows [SemVer](https://semver.org). The tag format is `vMAJOR.MINOR.PATCH`. Only stable releases go out: prereleases are tagged `-beta.N` and never pushed to the Homebrew cask.

## Checklist
1. [ ] Milestone issues closed, and the manual test matrix for the milestone recorded in its tracking issue
2. [ ] `make lint test` green locally and in CI on `main`
3. [ ] `CHANGELOG.md`: move *Unreleased* entries under the new version with today's date
4. [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`. `MARKETING_VERSION` is always plain `X.Y.Z` (macOS rejects a `-beta.N` suffix in `CFBundleShortVersionString`). A beta keeps the `X.Y.Z` it leads up to and only bumps the build number.
5. [ ] Release build: `make archive`, which produces `build/Mullion.app` (Release, universal arm64 + x86_64, Hardened Runtime, ad-hoc signed) and verifies its signature
6. [ ] **Signing**
   - **Decision (M3, 2026-10-21): v1.x ships without a Developer ID.** The project has no paid Apple Developer account. `make archive` ad-hoc signs, and the release notes and README explain *Open Anyway*. There is no `make notarize` target.
   - If a Developer ID is ever added: write `make notarize` (`xcrun notarytool submit --wait` with a keychain profile, then `xcrun stapler staple`), put the secrets in the `release` environment, and drop the Gatekeeper note.
7. [ ] `make dmg`, which produces `build/Mullion-X.Y.Z.dmg` and prints its SHA-256. Record it. For a beta: `make dmg RELEASE_VERSION=X.Y.Z-beta.N`.
8. [ ] Smoke test the DMG on a clean user account: install, grant Accessibility, try 3 shortcuts and 1 drag
9. [ ] Tag and publish, preferably through CI (see below): `git tag vX.Y.Z && git push origin vX.Y.Z`
10. [ ] Update the Homebrew cask in the own tap `iamAdarshh/homebrew-tap`. Not `homebrew/cask`: its casks have to pass Gatekeeper, which an un-notarized build doesn't.

## Releasing through CI (preferred)
Pushing a `v*` tag runs `.github/workflows/release.yml`, so the published files are built from exactly the tagged commit on a clean runner, not on your Mac.
1. The workflow waits for your approval: *Actions → Release → Review deployments → release → Approve*. This is the `release` environment's protection (*Settings → Environments → release*: you as required reviewer, deployment limited to `v*` tags), and it's where signing secrets will live once there is a Developer ID.
2. It checks that the tag matches `MARKETING_VERSION` (a `-beta.N` suffix is allowed), runs the tests, then builds with `make archive` and `make dmg`. It also makes a ZIP (`ditto`, for Homebrew and future auto-updates) and `checksums.txt`.
3. It creates a **draft** release. The notes are the matching `CHANGELOG.md` section plus the install note and the checksums, and tags with a `-` are marked as pre-releases.
4. Download the DMG from the draft and smoke test it (step 8), then click **Publish release**.

Steps 5–7 are still useful locally when you want to test a build before tagging.

## Release-note template
```markdown
## Mullion vX.Y.Z

### New
- …

### Fixed
- …

### Install
Download `Mullion-X.Y.Z.dmg`, drag Mullion to Applications, open it and grant Accessibility access.
<!-- unsigned builds only -->
> This build is not notarized, so macOS blocks it on first launch. Open it once, then go to
> System Settings → Privacy & Security and click **Open Anyway** (macOS 15 and later no longer
> offer right-click → Open for this). Or run `xattr -dr com.apple.quarantine /Applications/Mullion.app`.

SHA-256: `…`
```
